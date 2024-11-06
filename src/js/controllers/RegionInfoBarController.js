import { ElasticsearchModel } from '../models/ElasticSearchModel';
import { OSMSearchModel } from '../models/OSMSearchModel';
import { regionInfoBarConfig } from '../utilities/regionInfoBarConfig';
import { mapConfig } from '../utilities/mapConfig';
import { sdgScoreSetting } from '../utilities/settings';
import { ProgressBars } from '../visualisations/ProgressBars';
import { round, intersection, cloneDeep, uniq, capitalize, tail, sumBy, sum } from 'lodash';
import { DonutChart } from '../visualisations/DonutChart';
import { enums } from '../utilities/enums';
import { PyramidChart } from '../visualisations/PyramidChart';
import * as turf from '@turf/turf';
import PubSub from '../utilities/pubsub';

export class RegionInfoBarController {
    /******************************************************************************************************************************/
    // *** Public variables ***
    /******************************************************************************************************************************/
    // Class objects
    m_selectedRegionDOMRef;
    m_educationVisual;
    m_incomeVisual;
    m_carFuelTypeVisual;
    m_populationAgeVisual;
    m_populationGenderDiversityVisual;
    m_populationNationalityDiversityVisual;
    m_yearVsGenderDiversityVisual;

    // Data objects for this class
    m_mapOnClickData = { // When a region from the MapController is clicked and triggers the 'updateSubcomponents', the data queried specific to the region in this class are stored in this object
        regionRecord: {}, // Region selected record data
        regionTotalArea: 0, // Total area size of the selected region
        amenityData: {}, // Object containing data from current regions' amenity category data
        transportData: {}, // 
        landuseData: [] //
    }; 
    m_sdgScores = {}; // Stores the SDG scores from each SDG calculation

    m_mapModel;
    regionInfoBarConfig = cloneDeep(regionInfoBarConfig);
    regionInfoBarSettings = { concatId: '', color: 'black' }; // Initialize the settings object with default values

    /******************************************************************************************************************************/
    // *** Constructor and custom destroyer function ***
    /******************************************************************************************************************************/
    /**
     * 
     * @param {*} mapModel                                                      An object instance of the MapModel class, where the plots will be stored
     * @param { { concatId: string, color: string } } regionInfoBarSettings     An object to maintain the settings related to the regionInfoBar. 'color' - to represent which plot on the map the data in the bar represents and allows for future enhancements by using an object structure, 'concatID' - to differentiate an instance of this class with the other DOM_Containers created by the template, we append a unique ID to the default IDs on the template
    */
    constructor(mapModel, regionInfoBarSettings) {
        this.m_mapModel = mapModel;
        Object.assign(this.regionInfoBarSettings, regionInfoBarSettings);

        this.#_prepareRegionInfoBarConfig();
        this.#_initSubcomponents();
        this.#_init();
        this.#_scrollObserver();
    };

    destroyer = () => {
        // Delete all memory references to the layers created for an instance of this class when instance is deleted to keep memory clean and code execution smooth
        this.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_amenities}${this.regionInfoBarSettings.concatId}`, true);
        this.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_landuse}${this.regionInfoBarSettings.concatId}`, true);
        this.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_selected_region}${this.regionInfoBarSettings.concatId}`, true);

        // Unsubscribe to prevent memory leakage and any unwanted calls to an instance of this class when instance is deleted to keep memory clean and code execution smooth
        PubSub.unsubscribe('recalculateRegionScore');
    };

    /******************************************************************************************************************************/
    // *** Public methods ***
    /******************************************************************************************************************************/
    /**
     * Function called from a region click on the MapController to update the subcomponents attached with the current context of the sideNav controller
     * @param {{}} record           Data record based on region selected from MapController -> MapModel
     * @param {{}} geo_shapeKey     For info on these next 3 attributes follow the trace to MapModel clickEvent handler
     * @param {{}} invertLngLat
     * @param {{}} plotCoordinates
    */
    updateSubcomponents = (record, geo_shapeKey, invertLngLat, plotCoordinates) => {
        this.m_mapOnClickData = { regionRecord: record }; // Clear object from previous region selected on new click and load initially with the newly selected regions' data

        const subComponentPromises = [];

        this.m_selectedRegionDOMRef.textContent = record[this.regionInfoBarConfig.selectedRegion.key] ? record[this.regionInfoBarConfig.selectedRegion.key] : '-';

        this.m_educationVisual.updateVisual(record, true);

        this.m_incomeVisual.updateVisual(record, false);

        this.m_carFuelTypeVisual.updateVisual(record, true);

        this.m_populationAgeVisual.updateVisual(record, true);

        this.m_populationGenderDiversityVisual.updateVisual(record, false);

        this.m_populationNationalityDiversityVisual.updateVisual(record, false);

        this.m_yearVsGenderDiversityVisual.updateVisual(record, false);

        // Delete the existing overlayLayers used for the displaying 'Amenity', 'Transport', 'Landuse' info on the map
        this.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_landuse}${this.regionInfoBarSettings.concatId}`, true);
        this.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_amenities}${this.regionInfoBarSettings.concatId}`, true);
        this.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_transport}${this.regionInfoBarSettings.concatId}`, true);

        subComponentPromises.push(this.#_landUseVisualGenerate(record, geo_shapeKey, invertLngLat, plotCoordinates));

        subComponentPromises.push(this.#_transportOptionsExtract(record, geo_shapeKey, invertLngLat, plotCoordinates));

        subComponentPromises.push(this.#_amenitiesLocate(record, geo_shapeKey, invertLngLat, plotCoordinates));

        // Promise required to ensure all the data has been captured for each subComponent before starting regional score calculation
        Promise.all(subComponentPromises).then(resp => {
            this.#_calculateRegionScore(record, geo_shapeKey, invertLngLat, plotCoordinates);
        });

        PubSub.subscribe('recalculateRegionScore', (data) => { 
            this.#_calculateRegionScore(record, geo_shapeKey, invertLngLat, plotCoordinates);
        });
    };

    /******************************************************************************************************************************/
    // *** Private methods ***
    /******************************************************************************************************************************/
    /**
     * As a template is used for the RegionInfoBar section on the DOM, we require an update to the config, which maps to the init DOM_ContainerIds.
     * When a comparision mode is done, a new DOM RegionInfoBar template is created which requires a point to unique DOM_ContainerIds
     */
    #_prepareRegionInfoBarConfig() {
        Object.values(this.regionInfoBarConfig).forEach(categoryConfig => {
            if (categoryConfig.DOM_ContainerId) {
                categoryConfig.DOM_ContainerId += this.regionInfoBarSettings.concatId;
            }
        });
    };

    #_initSubcomponents() {
        this.m_elasticsearchModel = new ElasticsearchModel();
        this.m_osmSearchModel = new OSMSearchModel();

        this.m_incomeVisual = new DonutChart(this.regionInfoBarConfig.incomeVisual, undefined);
        this.m_educationVisual = new ProgressBars(this.regionInfoBarConfig.educationVisual, undefined);
        this.m_carFuelTypeVisual = new ProgressBars(this.regionInfoBarConfig.carFuelTypeVisual, ' Units');
        this.m_landuseBars = new ProgressBars({ DOM_ContainerId: `landuse_visual${this.regionInfoBarSettings.concatId}`, data: [] }, ' ac');
        this.m_populationAgeVisual = new ProgressBars(this.regionInfoBarConfig.populationAgeVisual, '');
        this.m_populationGenderDiversityVisual = new DonutChart(this.regionInfoBarConfig.populationGenderDiversityVisual, undefined);        
        this.m_populationNationalityDiversityVisual = new DonutChart(this.regionInfoBarConfig.populationNationalityDiversityVisual, undefined);
        this.m_yearVsGenderDiversityVisual = new PyramidChart(this.regionInfoBarConfig.yearVsGenderDiversityVisual, undefined);

        this.m_selectedRegionDOMRef = document.getElementById(this.regionInfoBarConfig.selectedRegion.DOM_ContainerId);
    };

    #_init() {
        this.m_mapModel.addOverlayLayer(`${enums.overlay_layer_KL_landuse}${this.regionInfoBarSettings.concatId}`, 'featureGroup'); // All landuse shapes will be plotted in this layer, which are generated on click of the 'KL_statistical_regions' shapes
        this.m_mapModel.addOverlayLayer(`${enums.overlay_layer_KL_amenities}${this.regionInfoBarSettings.concatId}`, 'featureGroup'); // All amenity shapes will be plotted in this layer, which are generated on click of the 'KL_statistical_regions' shapes
        this.m_mapModel.addOverlayLayer(`${enums.overlay_layer_selected_region}${this.regionInfoBarSettings.concatId}`, 'featureGroup');
        this.m_mapModel.addOverlayLayer(`${enums.overlay_layer_KL_transport}${this.regionInfoBarSettings.concatId}`, 'featureGroup');

        // Make regionInfoBar div clicked on the active div binded to the mapController object. Click on mapPlots will be handled by this regionInfoBarController object
        document.getElementById(`${enums.region_info_bar_container_Id}${this.regionInfoBarSettings.concatId}`).addEventListener('click', (event) => {
            if (event.target.id !== enums.compare_regions_button_Id) // When 'compare region' button is clicked from the 1st regionInfoBar, we stop the click event from considering this as a switch active context to the 1st regionInfoBar
                PubSub.publish('updateRegionInfoBarBoundToMap', this); // 'this' refers to the entire class object, which is used to update the regionInfoBarController object for the mapController object
        });
    };

    #_landUseVisualGenerate(record, geo_shapeKey, invertLngLat, plotCoordinates) {
        this.m_mapOnClickData.landuseData = []; // Empty dataset for every new region click event

        return new Promise((resolve, reject) => {
            var polygon = turf.polygon(record[geo_shapeKey].coordinates);
            this.m_mapOnClickData.regionTotalArea = this.#_convertShapeSizeToMetric(turf.area(polygon));
            //const totalAreaSize = this.#_convertShapeSizeToMetric(turf.area(polygon));
            document.getElementById(`landuse_totalArea${this.regionInfoBarSettings.concatId}`).innerText = round(this.m_mapOnClickData.regionTotalArea, 2);

            const requestData = this.m_elasticsearchModel._generateSearchRequestData();
            const elasticSearchFilterByConfig = cloneDeep(this.regionInfoBarConfig.landuseCategorisationVisual.elasticSearchFilterBy);
            elasticSearchFilterByConfig[0].filterQueryProperties.push({ dimension: mapConfig.mapPlotConfig.on_geoShapeKeyClick.geoShapeKey, dimensionType: 'geo_shape', value: record[geo_shapeKey].coordinates, geoFilter: { type: 'Polygon', relation: 'within' }  })
            elasticSearchFilterByConfig.forEach(elasticSearchFilter => {
                requestData.query = this.m_elasticsearchModel._generateFilterQuery(requestData.query, elasticSearchFilter.filterQueryType, elasticSearchFilter.filterQueryClause, elasticSearchFilter.filterQueryProperties);
            });

            this.m_elasticsearchModel.executeSearchWithRequestData(requestData, mapConfig.mapPlotConfig.on_geoShapeKeyClick.indexName).then(resp => {
                const dataVis = {};

                const OSMTagPropertiesConfig = this.regionInfoBarConfig.landuseCategorisationVisual.OSMTagsProperties
                const tagsToExtract = Object.keys(OSMTagPropertiesConfig);

                const ways = resp.hits.hits.filter(element => element._id.indexOf('way') > -1 && element._source.geolocation.type === 'Polygon');            

                ways.forEach(way => {
                    const polygon = turf.polygon([way._source.geolocation.coordinates[0]]);
                    way['area_size'] = this.#_convertShapeSizeToMetric(turf.area(polygon));
                    const tagKeys = intersection(Object.keys(way._source), tagsToExtract);
                    if (tagKeys.length === 0)
                        console.log('Empty tags: ' + Object.keys(way._source));
                    else {
                        tagKeys.forEach(tagKey => {
                            if ((dataVis[tagKey] && dataVis[tagKey].value) === undefined)
                                dataVis[tagKey] = { value: 0, count: 0 }; // value-area sum occupied by landuse category, count-number of locations under category(required for SDG density calculation)

                            dataVis[tagKey] = { 
                                value: ( isNaN(dataVis[tagKey].value) ? 0 : dataVis[tagKey].value ) + way['area_size'],
                                count: dataVis[tagKey].count + 1,
                                color: OSMTagPropertiesConfig[tagKey].color 
                            };
                        });

                        this.m_mapModel.plotShape(way._source, mapConfig.mapPlotConfig.geo_shapeKey, true, { color: (OSMTagPropertiesConfig[tagKeys[0]].color) ? OSMTagPropertiesConfig[tagKeys[0]].color : 'grey' }, `${enums.overlay_layer_KL_landuse}${this.regionInfoBarSettings.concatId}`);
                    }
                });

                const arr = [];
                Object.keys(dataVis).map((key) => arr.push({name: capitalize(key), key: key, value: dataVis[key].value, count: dataVis[key].count, color: dataVis[key].color}));
                this.m_landuseBars.reCreateProgressBars(arr);
                this.m_mapOnClickData.landuseData = arr;
                resolve(true);
            });
        });
    };

    #_transportOptionsExtract(record, geo_shapeKey, invertLngLat, plotCoordinates) {
        // To-do: For faster performance, update the perl script for KL OSM data to extract the type 'relation' better, so it contains the info for tag key 'route'
        
        this.m_mapOnClickData.transportData = {}; // For new region selected, reset the data stored
        
        return new Promise((resolve, reject) => {
            // Query and map all platforms for each routeType as defined in the config
            // Promise is used to ensure data is available before updating DOM section for transport, as the queries could return 'large' results
            const transportPlatformsQueryPromises = [];
            this.regionInfoBarConfig.transportRoutes.types.forEach(routeTypeConfig => {
                const platformPromise = this.m_osmSearchModel.getTagsByGeoLocation(routeTypeConfig.OSMPlatformTags, plotCoordinates, record[geo_shapeKey].type, invertLngLat).then(resp => {
                    this.m_mapOnClickData.transportData[`${enums.transportData_prefix_platforms}${routeTypeConfig.OSMRouteValue}`] = resp.elements;

                    this.m_mapOnClickData.transportData[`${enums.transportData_prefix_platforms}${routeTypeConfig.OSMRouteValue}`].forEach(element => {
                        switch(element.type) {
                            case 'relation':
                            case 'way': this.m_mapModel.plotPolygon(element, enums.osm_geoShapeKey, false, { color: routeTypeConfig.color ? routeTypeConfig.color : 'grey' }, `${enums.overlay_layer_KL_transport}${this.regionInfoBarSettings.concatId}`);
                                        break;
                            case 'node':    this.m_mapModel.plotPoint(element, enums.osm_geoShapeKey, false, { color: routeTypeConfig.color ? routeTypeConfig.color : 'grey' }, `${enums.overlay_layer_KL_transport}${this.regionInfoBarSettings.concatId}`);
                                            break;
                            default:    alert('Error!');
                                        break;
                        }
                    });

                });
                transportPlatformsQueryPromises.push(platformPromise);
            });

            // Query for all routeType options(travel options, i.e. bus numbers, trains numbers, etc.) and display options in DOM
            this.m_osmSearchModel.getTagsByGeoLocation([{tag: 'relation', key: 'route'}], plotCoordinates, record[geo_shapeKey].type, invertLngLat).then(resp => {
                // Delete previous DOM info if it exists
                const transportRoutesContainerDOMRef = document.getElementById(`transport_routes_container${this.regionInfoBarSettings.concatId}`);
                if (transportRoutesContainerDOMRef) {
                    transportRoutesContainerDOMRef.remove();
                }

                let transportRoutesContainer_HTML = ``;

                Promise.all(transportPlatformsQueryPromises).then(transportPlatformsQueriesResp => {
                    this.regionInfoBarConfig.transportRoutes.types.forEach(routeTypeConfig => {
                        const routeOptions = uniq(resp.elements.filter((el) => el.tags && el.tags.route === routeTypeConfig.OSMRouteValue).map(el => el.tags.ref));
        
                        this.m_mapOnClickData.transportData[`${enums.transportData_prefix_options}${routeTypeConfig.OSMRouteValue}`] = routeOptions;
        
                        if (routeOptions.length > 0) {
                            let transportRouteOptionsHTML = ``;
                            routeOptions.forEach(routeOption => {
                                transportRouteOptionsHTML += `<span class='transport_route_option'>${routeOption}</span>`;
                            });

                            transportRoutesContainer_HTML +=    `<div class="transport_route_container">
                                                                    <p class='sectionDescription transportRouteText'>${capitalize(routeTypeConfig.OSMRouteValue)} Network</p>
                                                                    <p class="sectionDescription transportPlatformText" style='color: ${routeTypeConfig.color}'>Platforms: ${this.m_mapOnClickData.transportData[`${enums.transportData_prefix_platforms}${routeTypeConfig.OSMRouteValue}`].length} </p>
                                                                    <div class="sectionDescription">
                                                                        ${transportRouteOptionsHTML}
                                                                    </div>
                                                                </div>`;
                        }
                    });
                    document.getElementById(this.regionInfoBarConfig.transportRoutes.DOM_ContainerId).insertAdjacentHTML("beforeend", `<div id='transport_routes_container${this.regionInfoBarSettings.concatId}'>${transportRoutesContainer_HTML}</div>`);
                    resolve(true);
                })
            });
        });
    };

    #_amenitiesLocate(record, geo_shapeKey, invertLngLat, plotCoordinates) {
        return new Promise((resolve, reject) => {
            // Delete previous DOM info if it exists
            let amenitiesContainerDOMRef = document.getElementById(`amenities_container${this.regionInfoBarSettings.concatId}`);
            if (amenitiesContainerDOMRef) {
                amenitiesContainerDOMRef.remove();
            }

            // Create the DOM element, as we will be running a loop, and we want to aggregate all the 'Amentity' visuals together
            document.getElementById(this.regionInfoBarConfig.amenitiesVisual.DOM_ContainerId).insertAdjacentHTML("beforeend", `<div id='amenities_container${this.regionInfoBarSettings.concatId}'></div>`);
            amenitiesContainerDOMRef = document.getElementById(`amenities_container${this.regionInfoBarSettings.concatId}`);

            this.m_mapOnClickData.amenityData = {}; // Empty dataset for every new region click event
            const amenityCategoryQueryPromises = []; // Empty promises array to store all queries promise event for amenity category information

            this.regionInfoBarConfig.amenitiesVisual.categories.forEach(amenityConfig => {
                const requestData = this.m_elasticsearchModel._generateSearchRequestData();

                const muncipalitySelectionFilter = { filterQueryType: 'bool',filterQueryClause: 'must', filterQueryProperties: [{ dimension: 'geolocation', dimensionType: 'geo_shape', value: record[geo_shapeKey].coordinates, geoFilter: { type: 'Polygon', relation: 'within' } }]};
                requestData.query = this.m_elasticsearchModel._generateFilterQuery(requestData.query, muncipalitySelectionFilter.filterQueryType, muncipalitySelectionFilter.filterQueryClause, muncipalitySelectionFilter.filterQueryProperties);

                // to-do update, to have the 'requestData.query.bool.must.push({});' be replaced with a push {} in the _generateFilterQuery function
                requestData.query.bool.must.push({});
                amenityConfig.elasticSearchFilterBy.forEach(elasticSearchFilter => {
                    const subRequestQuery = this.m_elasticsearchModel._generateFilterQuery(requestData.query.bool.must[requestData.query.bool.must.length - 1], elasticSearchFilter.filterQueryType, elasticSearchFilter.filterQueryClause, elasticSearchFilter.filterQueryProperties);
                });

                const amenityQueryPromise = this.m_elasticsearchModel.executeSearchWithRequestData(requestData, mapConfig.mapPlotConfig.on_geoShapeKeyClick.indexName).then(resp => {
                    this.m_mapOnClickData.amenityData[amenityConfig.amenityName] = resp.hits.hits;
                    resp.hits.hits.forEach(location => {
                        this.m_mapModel.plotShape(location._source, mapConfig.mapPlotConfig.geo_shapeKey, invertLngLat, { color: (amenityConfig.color) ? amenityConfig.color : 'grey' }, `${enums.overlay_layer_KL_amenities}${this.regionInfoBarSettings.concatId}`);
                    });

                    let amenityContainer_HTML = `<div class="amenity_container">
                                                    <p class='sectionDescription amenityText'>
                                                        <span style='color: ${amenityConfig.color}'>${capitalize(amenityConfig.amenityName)}</span>
                                                    </p>
                                                    <div class="sectionDescription">
                                                        ${resp.hits.hits.length}
                                                    </div>
                                                </div>`;
                    amenitiesContainerDOMRef.insertAdjacentHTML("beforeend", amenityContainer_HTML);
                });

                amenityCategoryQueryPromises.push(amenityQueryPromise);
            });

            Promise.all(amenityCategoryQueryPromises).then(resp => {
                resolve(true);
            }).catch(err => {
                reject('Error: Amenity promises failed to resolve!');
            });
        });
    };

    #_calculateRegionScore(record, geo_shapeKey, invertLngLat, plotCoordinates) {
        this.m_sdgScores = {}; // Reset scores on selection of new region or restarting calculations

        var polygon = turf.polygon(record[geo_shapeKey].coordinates);
        const regionAreaSize = this.#_convertShapeSizeToMetric(turf.area(polygon));

        const proRatedRegionSize = regionAreaSize/sdgScoreSetting.regionSettings.idealSize;

        // Amenity SDG score calculations
        const proRatedAmenityCategoryScores = {};
        regionInfoBarConfig.amenitiesVisual.categories.forEach(amenityCategoryConfig => {
            proRatedAmenityCategoryScores[amenityCategoryConfig.amenityName] = round(sdgScoreSetting.amenitiesScoreSettings.idealCounts[amenityCategoryConfig.amenityName] * proRatedRegionSize);

            // Ensuring the calculation does not cross value of 1(i.e. 100%) - (scale used here is 0-1)
            let amenityCount = this.m_mapOnClickData.amenityData[amenityCategoryConfig.amenityName].length;
            if (amenityCount > proRatedAmenityCategoryScores[amenityCategoryConfig.amenityName])
                amenityCount = proRatedAmenityCategoryScores[amenityCategoryConfig.amenityName];

            // Condition checked to ensure a case of (0/0) which is NaN does not occur
            this.m_sdgScores[`amenity_${amenityCategoryConfig.amenityName}`] = (amenityCount === proRatedAmenityCategoryScores[amenityCategoryConfig.amenityName] && amenityCount === 0) ? 0 : (amenityCount/proRatedAmenityCategoryScores[amenityCategoryConfig.amenityName]);
        });

        // Transport Lines SDG score calculations
        const proRatedTransportTypeScores = {};
        regionInfoBarConfig.transportRoutes.types.forEach(routeTypeConfig => {
            proRatedTransportTypeScores[routeTypeConfig.OSMRouteValue] = round(sdgScoreSetting.transportScoreSettings.idealCounts[routeTypeConfig.OSMRouteValue] * proRatedRegionSize);

            // Ensuring the calculation does not cross value of 1(i.e. 100%) - (scale used here is 0-1)
            let transportCount = this.m_mapOnClickData.transportData[`${enums.transportData_prefix_platforms}${routeTypeConfig.OSMRouteValue}`].length;
            if (transportCount > proRatedTransportTypeScores[routeTypeConfig.OSMRouteValue])
                transportCount = proRatedTransportTypeScores[routeTypeConfig.OSMRouteValue];

            // Condition checked to ensure a case of (0/0) which is NaN does not occur
            this.m_sdgScores[`transport_${routeTypeConfig.OSMRouteValue}`] = (transportCount === proRatedTransportTypeScores[routeTypeConfig.OSMRouteValue] && transportCount === 0) ? 0 : transportCount/proRatedTransportTypeScores[routeTypeConfig.OSMRouteValue];
        });

        // Education SDG score calculation
        let actualMeanYearsSchooling = 0;
        regionInfoBarConfig.educationVisual.data.forEach(educationData => {
            actualMeanYearsSchooling += (educationData.educationYears * record[educationData.key]);
        });
        actualMeanYearsSchooling = actualMeanYearsSchooling/100;
        // 'Expected Years of Schooling' is divided by hardcoded value as it is a universally accepted value for schooling years expected for a citizen below age of 25.
        this.m_sdgScores[`education`] = ((sdgScoreSetting.educationScoreSettings.idealCounts['Expected Years of Schooling']/18) + (actualMeanYearsSchooling/sdgScoreSetting.educationScoreSettings.idealCounts['Mean Years of Schooling']))/2;


        // Landuse SDG calculation
        let landuseIndex = 0;
        this.m_mapOnClickData.landuseData.forEach(landuseCategoryData => {
            const idealCategoryPercentage = sdgScoreSetting.landuseScoreSettings.idealCounts[landuseCategoryData.key];

            const actualCategoryPercentage = (landuseCategoryData.value/this.m_mapOnClickData.regionTotalArea) * 100;
            let categoryIndex = actualCategoryPercentage/idealCategoryPercentage;
            if (categoryIndex > 1) // Normalise to ensure index value stays within 0-1 range
                categoryIndex = 1;

            landuseIndex += categoryIndex;
        });
        const totalIdealLanduseWeightage = sum(Object.values(sdgScoreSetting.landuseScoreSettings.idealCounts))/100; // Requied for normalisation, in the event settings are updated to sum up beyond 100 as max value. Division by 100, because the values are in percentages
        this.m_sdgScores[`landuse`] = (landuseIndex/this.m_mapOnClickData.landuseData.length)/totalIdealLanduseWeightage;


        // Aggregate all score calculations for score of selected region
        let regionScore = 0;
        Object.values(this.m_sdgScores).forEach(score => {
            regionScore += score;
        });
        regionScore = round((regionScore/(Object.keys(this.m_sdgScores).length)), 2);

        document.getElementById(`regionScore${this.regionInfoBarSettings.concatId}`).innerText = isNaN(regionScore) ? 0 : regionScore;
    
        // Conditions to check and validate when the region score is zero and ensure a warning message is given to user to understand reasoning for zero
        if (regionScore === 0 && regionAreaSize < sdgScoreSetting.regionSettings.idealSize) {
            document.getElementById(`regionScore_errorMessage${this.regionInfoBarSettings.concatId}`).style.display = 'block';
        } else {
            document.getElementById(`regionScore_errorMessage${this.regionInfoBarSettings.concatId}`).style.display = 'none';
        }
    };

    /**
     * 
     * @param {number} shapeSize Numeric value of the shape size to be converted to metric system
     */
    #_convertShapeSizeToMetric(shapeSize) {
        return round(shapeSize * 0.000247105381, 2);
        //return round(shapeSize/1000000, 2);
    };

    /**
     * Function creates an observable which triggers whenever the window scroll to the 'Transport' section of the sidenav bar
     */
    #_scrollObserver() {
        const me = this;

        let prev_topmostInfoSection;
        const infoSectionObserver = new IntersectionObserver((entries) => {
                const topmostInfoSection = entries.filter(entry => entry.isIntersecting)
                                        .sort((a, b) => a.intersectionRatio - b.intersectionRatio)
                                        .map(entry => entry.target)
                                        .shift();

                if (topmostInfoSection) {
                    // BEFORE INFO SECTION SPECIFIC CODE EXECUTION - Statements which are to be executed irrespective of active info section
                    if (prev_topmostInfoSection) {
                        prev_topmostInfoSection.classList.remove('active_info_section');
                    }
                    prev_topmostInfoSection = topmostInfoSection;
                    topmostInfoSection.classList.add('active_info_section');

                    // Custom code based on active info section
                    switch(topmostInfoSection.id) {
                        case 'landuse_info':    me.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_amenities}${this.regionInfoBarSettings.concatId}`);
                                                me.m_mapModel.showOverlayLayer(`${enums.overlay_layer_KL_landuse}${this.regionInfoBarSettings.concatId}`);

                                                me.m_mapModel.overlayLayers[`${enums.overlay_layer_selected_region}${this.regionInfoBarSettings.concatId}`].setStyle({ 'fillOpacity': 0.05 });
                                                // const selectedRegionCoordinates = [];
                                                // me.m_mapModel.overlayLayers[enums.overlay_layer_selected_region].eachLayer(layer => { selectedRegionCoordinates.push(layer.getLatLngs()); });
                                                // me.m_mapModel.map.fitBounds(selectedRegionCoordinates[0]);
                                                break;
                        case 'transport_lines': me.m_mapModel.switchBaseLayer(enums.baselayer_transport);
                                                me.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_landuse}${this.regionInfoBarSettings.concatId}`);
                                                me.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_amenities}${this.regionInfoBarSettings.concatId}`);
                                                me.m_mapModel.showOverlayLayer(`${enums.overlay_layer_KL_transport}${this.regionInfoBarSettings.concatId}`);                                                
                                                me.m_mapModel.createLegend(regionInfoBarConfig.transportRoutes.types.map(transportType => { return {label: transportType.OSMRouteValue, color: transportType.color, indicator: 'icon'} }), enums.overlay_legend_transport_routes, 'Transport Lines Legend');

                                                me.m_mapModel.overlayLayers[`${enums.overlay_layer_selected_region}${this.regionInfoBarSettings.concatId}`].setStyle({ 'fillOpacity': 0.05 });
                                                break;
                        case 'amenities':   me.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_landuse}${this.regionInfoBarSettings.concatId}`);
                                            me.m_mapModel.showOverlayLayer(`${enums.overlay_layer_KL_amenities}${this.regionInfoBarSettings.concatId}`);
                                            me.m_mapModel.overlayLayers[`${enums.overlay_layer_selected_region}${this.regionInfoBarSettings.concatId}`].setStyle({ 'fillOpacity': 0.05 });
                                            break;
                        default:    me.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_amenities}${this.regionInfoBarSettings.concatId}`);
                                    me.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_landuse}${this.regionInfoBarSettings.concatId}`);
                                    me.m_mapModel.removeLegend(enums.overlay_legend_transport_routes);
                                    break;
                    }

                    // AFTER INFO SECTION SPECIFIC CODE EXECUTION - Statements which are to be executed irrespective of active info section
                    if (topmostInfoSection.id !== 'transport_lines') { // Other sections will show the default map layer
                        me.m_mapModel.switchBaseLayer(enums.baselayer_default);
                        me.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_KL_transport}${this.regionInfoBarSettings.concatId}`);
                        me.m_mapModel.removeLegend(enums.overlay_legend_transport_routes);
                    }
                    if (topmostInfoSection.id !== 'landuse_info' && topmostInfoSection.id !== 'amenities' && topmostInfoSection.id !== 'transport_lines') {
                        me.m_mapModel.overlayLayers[`${enums.overlay_layer_selected_region}${this.regionInfoBarSettings.concatId}`].setStyle({ 'fillOpacity': 0.2 });
                    }
                }
            },
            {
                root: document.getElementById(`${enums.region_info_bar_container_Id}`),
                //rootMargin: "0px",
                threshold: 0.5, // Adjust the threshold as needed
            }
        );
        
        document.querySelectorAll(".info_section").forEach(divElement => {
            infoSectionObserver.observe(divElement);
        });
    };

    
}