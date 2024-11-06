export const regionInfoBarConfig = {
    selectedRegion: {
        DOM_ContainerId: 'regionSelected',
        key: 'description', // key in the index which stores the municpality name
    },
    educationVisual: { // This is the progressBar config
        DOM_ContainerId: 'education_bars',
        data: [
            { color: 'black', name: 'Hauptschulabschluss', key: 'SB_SBI_P_Hauptsch', educationYears: 9 }, // Key 'educationYears' specific to only educationVisual for region index calculation for the total number of years of education required to obtain this formal education from start grade 1
            { color: 'black', name: 'Realschulabschluss', key: 'SB_SBI_P_Realsch', educationYears: 10 },
            { color: 'black', name: 'Fachhochschulreife', key: 'SB_SBI_P_Fachhoch', educationYears: 17 },
            { color: 'black', name: 'Abitur', key: 'SB_SBI_P_Abitur', educationYears: 13 },
            { color: 'black', name: 'ohne/anderer Schulabschluss', key: 'SB_SBI_P_koaAbsch', educationYears: 14 }
        ]
    },
    incomeVisual: { // This is the donutChart config
        DOM_ContainerId: 'income_visual',
        data: [
            { name: '< 1100', key: 'SB_EIN_A_Einkommen_bis1100', color: 'brown' },
            { name: '1100 - 1500', key: 'SB_EIN_A_Einkommen_1100bis1500', color: 'blue' },
            { name: '1500 - 2000', key: 'SB_EIN_A_Einkommen_1500bis2000', color: 'orange' },
            { name: '2000 - 2600', key: 'SB_EIN_A_Einkommen_2000bis2600', color: 'maroon' },
            { name: '2600 - 4000', key: 'SB_EIN_A_Einkommen_2600bis4000', color: 'slate' },
            { name: '4000 - 7500', key: 'SB_EIN_A_Einkommen_4000bis7500', color: 'lime' },
            { name: '> 7500', key: 'SB_EIN_A_Einkommen_7500undgr', color: 'olive' }
        ]
    },
    transportRoutes: {
        DOM_ContainerId: 'transport_lines',
        types: [
            {
                OSMRouteValue: 'bus', // Value as per the OSM data, for key value 'route', check OSMTagInfo site for more info. (It is case-sensitive)
                OSMPlatformTags: [
                    {tag: 'nwr', key: 'highway', value: 'bus_stop'}
                ],
                color: 'red'
            },
            {
                OSMRouteValue: 'train', // Value as per the OSM data, for key value 'route', check OSMTagInfo site for more info. (It is case-sensitive)
                OSMPlatformTags: [
                    {tag: 'nwr', key: 'railway', value: 'platform'}
                ],
                color: 'orange'
            }
        ]
    },
    carFuelTypeVisual: { // This is the donutChart config
        DOM_ContainerId: 'car_fuel_type',
        data: [ // The 'name' values defined by 'key' is as defined per standard. Link: https://de.wikipedia.org/wiki/Kraftstoffcode
            { name: 'Benzin', key: '1', color: 'red' },
            { name: 'Diesel', key: '2', color: 'blue' },
            { name: 'Vielstoff', key: '3', color: 'orange' },
            { name: 'reines Elektrofahrzeug', key: '4', color: 'purple' },
            { name: 'Flüssiggas (LPG) - Autogas, Gasfahrzeug', key: '5', color: 'yellow' },
            { name: 'bivalenter Betrieb mit Benzin oder Flüssiggas (LPG) - Autogas, Gasfahrzeug', key: '6', color: 'green' },
            { name: 'bivalenter Betrieb mit Benzin oder komprimiertem Erdgas (CNG) - Gasfahrzeug', key: '7', color: 'black' },
            { name: 'kombinierter Betrieb mit Benzin und Elektromotor - Hybridelektrokraftfahrzeug', key: '8', color: 'brown' },
            { name: 'Erdgas (NG)', key: '9', color: '' },
            { name: 'kombinierter Betrieb mit Diesel und Elektromotor - Hybridelektrokraftfahrzeug', key: '10', color: '' },
            { name: 'Wasserstoff - Wasserstoffantrieb in einem Wasserstoffverbrennungsmotor', key: '11', color: '' },
            { name: 'kombinierter Betrieb mit Wasserstoff und Elektromotor', key: '12', color: '' },
            { name: 'bivalenter Betrieb mit Wasserstoff oder Benzin', key: '13', color: '' },
            { name: 'bivalenter Betrieb mit Wasserstoff oder Benzin kombiniert mit Elektromotor', key: '14', color: '' },
            { name: 'Brennstoffzelle mit Primärenergie Wasserstoff - Brennstoffzellenfahrzeug', key: '15', color: '' },
            { name: 'Brennstoffzelle mit Primärenergie Benzin', key: '16', color: '' },
            { name: 'Brennstoffzelle mit Primärenergie Methanol - Direktmethanolbrennstoffzelle', key: '17', color: '' },
            { name: 'Brennstoffzelle mit Primärenergie Ethanol', key: '18', color: '' }
        ]
    },
    populationAgeVisual: { // This is the progressBar config
        DOM_ContainerId: 'population_age_visual',
        data: [
            { color: 'black', name: '0-3', key: 'ew_gesamt_0_bis_unter_3' },
            { color: 'black', name: '3-6', key: 'ew_gesamt_3_bis_unter_6' },
            { color: 'black', name: '6-10', key: 'ew_gesamt_6_bis_unter_10' },
            { color: 'black', name: '10-16', key: 'ew_gesamt_10_bis_unter_16' },
            { color: 'black', name: '16-18', key: 'ew_gesamt_16_bis_unter_18' },
            { color: 'black', name: '18-30', key: 'ew_gesamt_18_bis_unter_30' },
            { color: 'black', name: '30-40', key: 'ew_gesamt_30_bis_unter_40' },
            { color: 'black', name: '40-50', key: 'ew_gesamt_40_bis_unter_50' },
            { color: 'black', name: '50-60', key: 'ew_gesamt_50_bis_unter_60' },
            { color: 'black', name: '60-70', key: 'ew_gesamt_60_bis_unter_70' },
            { color: 'black', name: '70-80', key: 'ew_gesamt_70_bis_unter_80' },
            { color: 'black', name: '>80', key: 'ew_gesamt_80_und_aelter' }
        ],
        periodSettings: {
            key: 'datum',   // A dimension of type 'Date', generated from an Aggregation query which would help visualise data over all available date ranges
            isInitLoadAsc: true,
            description: 'Play Timeline - Years'
        }
    },
    populationGenderDiversityVisual: { // This is the donutChart config
        DOM_ContainerId: 'gender_diversity',
        data: [
            { color: 'gray', name: 'Male', key: 'm_gesamt' },
            { color: 'black', name: 'Female', key: 'w_gesamt' }
        ],
        periodSettings: {
            key: 'datum', // A dimension of type 'Date', generated from an Aggregation query which would help visualise data over all available date ranges
            isInitLoadAsc: true,
            description: 'Play Timeline - Years'
        },
        visual_settings: {
            hideVisualLegend: true,
            innerRadiusMultiple: 0.8,
            textInMiddle: (data) => {{ // Displays the % of female diversity
                                        let total = 0;
                                        let textInMiddleValue;
                                        data.forEach(d => {
                                            total += Number(d.value);
                                            if (d.key === 'w_gesamt')
                                                textInMiddleValue = Number(d.value);
                                        });
                                        const result = (!(textInMiddleValue === 0 && total === 0)) ? ((textInMiddleValue/total) * 100).toFixed(0) : 0;
                                        return (!isNaN(result) ? (result + '%') : '');
                                    }}
        }
    },
    populationNationalityDiversityVisual: { // This is the donutChart config
        DOM_ContainerId: 'nationality_diversity',
        data: [
            { color: 'gray', name: 'All Citizens', key: 'ew_gesamt' },
            { color: 'black', name: 'Foreigners', key: 'davon_auslaender_gesamt' }
        ],
        periodSettings: {
            key: 'datum', // A dimension of type 'Date', generated from an Aggregation query which would help visualise data over all available date ranges
            isInitLoadAsc: true,
            description: 'Play Timeline - Years'
        },
        visual_settings: {
            hideVisualLegend: true,
            innerRadiusMultiple: 0.8,
            textInMiddle: (data) => {{ // Displays the % of foreign nationality diversity
                let totalCitizen = 0, totalForeigners = 0;
                data.forEach(d => {
                    if (d.key === 'davon_auslaender_gesamt')
                        totalForeigners += Number(d.value);
                    else if (d.key === 'ew_gesamt')
                        totalCitizen += Number(d.value);
                });
                const result = !(totalForeigners === 0 && totalCitizen === 0) ? ((totalForeigners/totalCitizen) * 100).toFixed(0) : 0;
                return (!isNaN(result) ? (isFinite(result) ? (result + '%') : '0%') : '');
            }}
        }
    },
    yearVsGenderDiversityVisual: { // This is the pyramidChart config
        DOM_ContainerId: 'year_gender_diversity_visual',
        dataKeys: {
            leftCategory: { key: 'm_gesamt', name: 'Male', color: 'blue' },
            rightCategory: { key: 'w_gesamt', name: 'Female', color: 'red' },
            groupCategory: {
                key: 'datum',
                name: 'Date', 
                processText:(data, periodKey) => { 
                    return new Date(Number(periodKey)).getFullYear();
                } 
            }
        },
        periodSettings: {
            key: 'datum' // A dimension of type 'Date', generated from an Aggregation query which would help visualise data over all available date ranges
        },
        visual_settings: {
            hideVisualLegend: false
        }
    },
    amenitiesVisual: { // Unique config - the sidebar contains a visual representing the breakdown of the amenities in a statistical region
        DOM_ContainerId: 'amenities',
        categories: [
            {
                amenityName: 'Pharmacy',
                color: 'red',
                elasticSearchFilterBy: [
                    {
                        filterQueryType: 'bool',
                        filterQueryClause: 'should', // this queryClause essentially is an OR operation for the properties below
                        filterQueryProperties: [ // All possible OSM tag:value pairs to reflect on pharmacies to be provided below
                            { dimension: 'healthcare', dimensionType: 'keyword', value: 'pharmacy' },
                            { dimension: 'shop', dimensionType: 'keyword', value: 'chemist' },
                            { dimension: 'amenity', dimensionType: 'keyword', value: 'pharmacy' }
                        ]
                    }
                ]
            },
            {
                amenityName: 'Grocery',
                color: 'green',
                elasticSearchFilterBy: [
                    {
                        filterQueryType: 'bool',
                        filterQueryClause: 'should', // this queryClause essentially is an OR operation for the properties below
                        filterQueryProperties: [ // All possible OSM tag:value pairs to reflect on pharmacies to be provided below
                            { dimension: 'shop', dimensionType: 'keyword', value: 'supermarket' },
                            { dimension: 'shop', dimensionType: 'keyword', value: 'grocery' },
                            { dimension: 'shop', dimensionType: 'keyword', value: 'convenience' },
                            { dimension: 'shop', dimensionType: 'keyword', value: 'corner_shop' }
                        ]
                    }
                ]
            }
        ]
    },
    landuseCategorisationVisual: { // Unique config - the sidebar contains a visual representing the breakdown of all the landuse categorisations, the config will be controlled from here, as the categorisation is done upon region selected
        elasticSearchFilterBy: [
            {
                filterQueryType: 'bool',
                filterQueryClause: 'must',
                filterQueryProperties: [
                    // { dimension: 'geolocation', dimensionType: 'geo_shape', geoFilter: { relation: 'within' }  },
                    // { dimension: 'landuse', dimensionType: 'exists' }
                ]
            }
        ],
        OSMTagsProperties: {
            'building': {color: '#2529a6'},
            'amenity': {color: '#fa667c'},
            'leisure': {color: '#ffbfbf'},
            'residential': {color: '#7025a6'},
            'highway': {color: '#b3de69'},
            'natural': {color: 'green'},
            'waterway': {color: 'blue'},
            'power': {color: '#595959'},
            'other': {color: '#6c6f8e'},
            'landuse': {color: 'yellow'},
        }
    },
};