import { MapModel } from '../models/MapModel';
import { ElasticsearchModel } from '../models/ElasticSearchModel';
import { OSMSearchModel } from '../models/OSMSearchModel';
import { regionInfoBarConfig } from '../utilities/regionInfoBarConfig';
import { mapConfig } from '../utilities/mapConfig';
import { uniq } from 'lodash';
import { enums } from '../utilities/enums';

export class MapController {
    /******************************************************************************************************************************/
    // *** Public variables ***
    /******************************************************************************************************************************/
    m_regionInfoBarController; // Refers to the current regionInfoBarController binded to the map click context
    m_mapModel;
    m_elasticsearchModel;
    m_osmSearchModel;

    /******************************************************************************************************************************/
    // *** Constructor and custom destroyer function ***
    /******************************************************************************************************************************/
    constructor() {
        this.#_bindFunctionsToCurrentContext();
        this.#_initSubcomponents();
        this.#_init();
    };

    /******************************************************************************************************************************/
    // *** Public methods ***
    /******************************************************************************************************************************/
    bindSideNavController = (regionInfoBarController) => {
        this.m_regionInfoBarController = regionInfoBarController; 
    };

    /******************************************************************************************************************************/
    // *** Private methods ***
    /******************************************************************************************************************************/
    #_initSubcomponents() {
        this.m_elasticsearchModel = new ElasticsearchModel();
        this.m_osmSearchModel = new OSMSearchModel();
        this.m_mapModel = new MapModel(mapConfig.initMapConfig);
    };

    #_init() {
        // Create a new map base layer
        this.m_mapModel.addBaseLayer(enums.baselayer_transport, 'https://tileserver.memomaps.de/tilegen/{z}/{x}/{y}.png', 'https://memomaps.de/en/homepage/');

        // Create all the overlay layer for the map, required to support various visuals
        this.m_mapModel.addOverlayLayer(enums.overlay_layer_KL_statistical_regions, 'featureGroup'); // All statistical regions will be plotted on this new layer created. Will help with maintainance and supporting multiple layers of views on the map
        this.m_mapModel.addOverlayLayer(enums.overlay_layer_KL_muncipality_regions, 'featureGroup'); // All muncipality regions will be plotted on this new layer created. Will help with maintainance and supporting multiple layers of views on the map

        // On first load, show only the 'statistical_region' layer
        this.m_mapModel.hideOverlayLayer(enums.overlay_layer_KL_muncipality_regions);

        // Query for respective map view data and plot shapes in overlay layers
        this.#_getDataForMap(enums.ESIndex_dataFor_statistical_map, enums.overlay_layer_KL_statistical_regions, 'm_statistical_data', mapConfig.mapPlotConfig.geo_shapeKey, {fillOpacity: 0.1, color: 'black'}, this._onClickOfStatisticalRegion);
        this.#_getDataForMap(enums.ESIndex_dataFor_muncipality_map, enums.overlay_layer_KL_muncipality_regions, 'm_muncipality_data', mapConfig.muncipalityConfig.geo_shapeKey, {fillOpacity: 0.1, color: 'black'}, this._onClickOfMuncipalityRegion);
    };

    /**
     * Function queries for respective map view data and plot shapes in defined overlay layers
     * @param {*} dataFor               As per config, the respective ESIndices will be queried for and merged
     * @param {*} overlayName           Overlay name, which will store all the shapes plotted for each record
     * @param {*} saveDataIn            All queried and merged data will be stored in a globally accessible variable for future operations, under 'this' context
     * @param {*} geo_shapeKey          Key/Dimension from ESIndex which stores shape data
     * @param {*} plotShapeOptions      Plot shape metadata 
     * @param {*} clickEventFunction    Click event function callback on plot shape
     */
    #_getDataForMap(dataFor, overlayName, saveDataIn, geo_shapeKey, plotShapeOptions, clickEventFunction) {
        const promisesForMapData = [];
        mapConfig.elasticsearchIndexes.forEach(elasticsearchIndex => {
            if (elasticsearchIndex && elasticsearchIndex.dataFor === dataFor) {
                if (elasticsearchIndex.elasticSearchAggregationQuery) {
                    const searchAggregationQuery = this.m_elasticsearchModel._generateAggregateQuery({}, elasticsearchIndex.elasticSearchAggregationQuery.dimensions);
                    const promise = this.m_elasticsearchModel.executeSearchWithRequestData(searchAggregationQuery, elasticsearchIndex.indexName, { responseProcessType: elasticsearchIndex.elasticSearchAggregationQuery.responseProcessType, indexName: elasticsearchIndex.indexName, flatAggregationKey: elasticsearchIndex.elasticSearchAggregationQuery.dimensions[0].fieldName, periodKey: (elasticsearchIndex.elasticSearchAggregationQuery.responseProcessType === enums.response_process_type_2DimensionAgg_FlatPeriodic ? elasticsearchIndex.elasticSearchAggregationQuery.dimensions[1].fieldName : undefined) });
                    promisesForMapData.push(promise);
                } else {
                    const promise = this.m_elasticsearchModel.queryAllDimensionsForIndex(elasticsearchIndex.indexName);
                    promisesForMapData.push(promise);
                }
            }
        });

        Promise.all(promisesForMapData).then(responses => {
            if (responses && responses.length >= 2) {
                let dataSet1 = responses[0];
                let dataSet2 = responses[1];
                let responseIndexCounter = 2;
                let response1Index = dataSet1[0]._index;
                let response2Index = dataSet2[0]._index;
                let isDataSet1Merged = false;
    
                while (dataSet1 && dataSet2 && responseIndexCounter <= responses.length) {
                    let arr1MergeBy, arr2MergeBy;
    
                    mapConfig.elasticsearchIndexes.some(elasticsearchIndex => {
                        if (elasticsearchIndex.indexName === response1Index) {
                            arr1MergeBy = elasticsearchIndex.mergeBy;
                        } else if (elasticsearchIndex.indexName === response2Index) {
                            arr2MergeBy = elasticsearchIndex.mergeBy;
                        }
    
                        if (arr1MergeBy && arr2MergeBy)
                            return true;
                    });

                    this[saveDataIn] = this.#_merge2ArrayOfObjectsByKey(dataSet1, dataSet2, arr1MergeBy, arr2MergeBy, isDataSet1Merged);
                    dataSet1 = this[saveDataIn];
                    dataSet2 = responses[responseIndexCounter++];
                    response2Index = dataSet2 && dataSet2[0] ? dataSet2[0]._index : undefined;
                    isDataSet1Merged = true;
                }
            } else {
                this[saveDataIn] = responses[0].map(obj => obj._source);
            }

            this.m_mapModel.plotMap(this[saveDataIn], geo_shapeKey, mapConfig.mapPlotConfig.invertLngLat, plotShapeOptions, overlayName, clickEventFunction);
        });
    };

    #_onClickOfStatisticalRegion(record, geo_shapeKey, invertLngLat, plotCoordinates) {
        // Delete existing selected_region overlay, and create a new plot to highlight selected region on map
        this.m_mapModel.hideOverlayLayer(`${enums.overlay_layer_selected_region}${this.m_regionInfoBarController.regionInfoBarSettings.concatId}`, true);
        this.m_mapModel.plotPolygon(record, geo_shapeKey, true, { color: this.m_regionInfoBarController.regionInfoBarSettings.color }, `${enums.overlay_layer_selected_region}${this.m_regionInfoBarController.regionInfoBarSettings.concatId}`);
        this.m_mapModel.map.fitBounds(plotCoordinates); // Zoom into the selected region on the map

        this.m_regionInfoBarController.updateSubcomponents(record, geo_shapeKey, invertLngLat, plotCoordinates);
    };

    #_onClickOfMuncipalityRegion(record, geo_shapeKey, invertLngLat, plotCoordinates) {
        // All records('m_statistical_data') are filtered by using the mapping from the 'record'(parameter) which is a muncipality record
        // The muncipality record has a mapping, which contains all the statistical regions which fall under it
        const matched_records_by_statistical_regions = this.m_statistical_data.filter(obj => {
            return record[mapConfig.muncipalityConfig.statisticalIdMappingKey].includes(Number(obj[mapConfig.muncipalityConfig.statisticalIdKey]));
        });

        // Merge all matched records into 1, to aggregate all statistical region info
        // Merge on keys referenced from the configs which are used for the sidenav
        const aggregateRecord = {};
        const periodAggregateRecord = {};
        let periodKeys = [];
        Object.keys(regionInfoBarConfig).forEach(sideBarConfigKey => {
            if (regionInfoBarConfig[sideBarConfigKey].periodSettings) {
                if (!periodAggregateRecord[regionInfoBarConfig[sideBarConfigKey].periodSettings.key]) {
                    periodAggregateRecord[regionInfoBarConfig[sideBarConfigKey].periodSettings.key] = {};
                }
                periodKeys.push(regionInfoBarConfig[sideBarConfigKey].periodSettings.key);
            } else if (regionInfoBarConfig[sideBarConfigKey].data) {
                regionInfoBarConfig[sideBarConfigKey].data.forEach(dataObj => {
                    aggregateRecord[dataObj.key] = 0;
                });
            }
        });

        // If the config reuses a periodKey(possible for multiple different visuals), remove the duplicates to avoid processing multiple times
        periodKeys = uniq(periodKeys); 

        matched_records_by_statistical_regions.forEach(matched_record => {
            Object.keys(aggregateRecord).forEach(aggKey => {
                aggregateRecord[aggKey] += (matched_record[aggKey] && Number(matched_record[aggKey])) ? Number(matched_record[aggKey]) : 0;
            });

            if (periodKeys && periodKeys.length > 0) {
                periodKeys.forEach(periodKey => {
                    if (matched_record[periodKey]) {
                        // Inside each periodKey, is an object which contains keys which are of type Date, to represent a time period, they furthur expand into an object which contains values associated with that time period
                        Object.keys(matched_record[periodKey]).forEach(periodDateKey => {
                            if (!periodAggregateRecord[periodKey][periodDateKey]) {
                                periodAggregateRecord[periodKey][periodDateKey] = {};
                            }

                            Object.keys(matched_record[periodKey][periodDateKey]).forEach(periodAggKey => {
                                if (!periodAggregateRecord[periodKey][periodDateKey][periodAggKey]) {
                                    periodAggregateRecord[periodKey][periodDateKey][periodAggKey] = 0;
                                }
                                periodAggregateRecord[periodKey][periodDateKey][periodAggKey] += (matched_record[periodKey][periodDateKey][periodAggKey] && Number(matched_record[periodKey][periodDateKey][periodAggKey])) ? Number(matched_record[periodKey][periodDateKey][periodAggKey]) : 0;
                            });
                        });
                    }
                });
            }
        });

        aggregateRecord[regionInfoBarConfig.selectedRegion.key] = record[mapConfig.muncipalityConfig.nameKey];
        aggregateRecord[geo_shapeKey] = record[geo_shapeKey];

        // Using the aggregation of all statistical region data which forms the muncipality selected, load the sideNav visuals
        this._onClickOfStatisticalRegion({...aggregateRecord, ...periodAggregateRecord}, geo_shapeKey, invertLngLat, plotCoordinates);
    };

    #_merge2ArrayOfObjectsByKey(arr1, arr2, arr1MergeBy, arr2MergeBy, isDataSet1Merged) {
        if (arr1MergeBy.type !== arr2MergeBy.type) {
            throw new Error('Trying to merge 2 arrays by keys of a different dataType!');
        }

        const mergedData = arr1.map((obj1) => {
            obj1 = isDataSet1Merged ? obj1 : obj1._source;
            const matchedObjs = arr2.filter((obj2) => {
                switch (arr1MergeBy.type) {
                    case 'number': return Number(obj2._source[arr2MergeBy.key]) === Number(obj1[arr1MergeBy.key]);
                    default: return obj2._source[arr2MergeBy.key] === obj1[arr1MergeBy.key];
                }
            });

            if (matchedObjs[0] && matchedObjs[0]._source)
                return { ...obj1, ...matchedObjs[0]._source };
            else
                return { ...obj1 };
        });

        return mergedData;
    };

    #_bindFunctionsToCurrentContext() {
        this._onClickOfStatisticalRegion = this.#_onClickOfStatisticalRegion.bind(this); // '#_onClickOfStatisticalRegion' function is passed as a parameter to function 'plotMap'. This will allow the 'this' context to be maintained in current class
        this._onClickOfMuncipalityRegion = this.#_onClickOfMuncipalityRegion.bind(this);
    };

}