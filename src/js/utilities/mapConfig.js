import { enums } from "./enums";

export const mapConfig = {
    // mapConfig stores the setting for leaflet map 
    initMapConfig: {
        DOM_Id: 'map', // The HTML DOM element id which the map should be loaded on
        minZoom: 4,
        maxZoom: 18,
        zoom: 12, // magnification with which the map will start
        lat: 49.4401, // lat, lng - co-ordinates to point the map to initially
        lng: 7.7491
    },
    mapPlotConfig: {
        geo_shapeKey: 'geolocation', // Key in elasticsearch indexes should be of type 'geo_shape' to plot. Key should exists in responses from the config key 'elasticsearchIndexes', with 'dataFor'='map'
        invertLngLat: true, // Leaflet takes coordinates in the format LatLng, if the data source has stored data in LngLat format, reversing the order is required
        on_geoShapeKeyClick: {
            indexName: 'kaiserslautern_openstreetmap',
            geoShapeKey: 'geolocation' // key in the index used under 'on_geoShapeKeyClick', which will filter the index Data
        }
    },
    muncipalityConfig: {
        nameKey: 'municipality_name', // Dimension from the muncipality_shape ESIndex, which contains the name of muncipality
        statisticalIdMappingKey: 'STAT_BEZ_Ids', // Dimension from the muncipality_shape ESIndex, which contains the mappings of a muncipality to all the statistical regions under it
        statisticalIdKey: 'STAT_BEZ', // Dimension from the data merged from 'dataFor' key of 'enums.ESIndex_dataFor_statistical_map'. NOTE: Any of the "mergeBy.key" values can be used
        geo_shapeKey: 'geolocation'
    },
    elasticsearchIndexes: [
        {
            indexName: 'shape_data_kaiserslautern_statistical_regions',
            mergeBy: {
                key: 'name',
                type: 'number'
            },
            dataFor: enums.ESIndex_dataFor_statistical_map
        },
        {
            indexName: 'stat_bezirk_soziodemo_mv2022',
            mergeBy: {
                key: 'STAT_BEZ',
                type: 'number'
            },
            dataFor: enums.ESIndex_dataFor_statistical_map
        },
        {
            indexName: 'kaiserslautern_kfz',
            mergeBy: {
                key: 'STAT_BEZ.keyword',
                type: 'number'
            },
            dataFor: enums.ESIndex_dataFor_statistical_map,
            elasticSearchAggregationQuery: {
                dimensions: [ // order of the array matters! It will aggregate the first array index as the first substructure and so on...
                                {fieldName: 'STAT_BEZ.keyword'},
                                {fieldName: 'car_fuel_type_key.keyword'}
                            ],
                responseProcessType: enums.response_process_type_2DimensionAgg_Flat
            }
        },
        {
            indexName: 'aggregation_20230718_statistische_bezirke_ohne_asterisk',
            mergeBy: {
                key: 'stat_bez_id.keyword',
                type: 'number'
            },
            dataFor: enums.ESIndex_dataFor_statistical_map,
            elasticSearchAggregationQuery: {
                dimensions: [ // order of the array matters! It will aggregate the first array index as the first substructure and so on...
                                {fieldName: 'stat_bez_id.keyword'},
                                {fieldName: 'datum', top_hits: ['datum', 'm_gesamt', 'w_gesamt', 'ew_gesamt', 'davon_auslaender_gesamt', 'ew_gesamt_0_bis_unter_3', 'ew_gesamt_3_bis_unter_6', 'ew_gesamt_6_bis_unter_10', 'ew_gesamt_10_bis_unter_16', 'ew_gesamt_16_bis_unter_18', 'ew_gesamt_18_bis_unter_30', 'ew_gesamt_30_bis_unter_40', 'ew_gesamt_40_bis_unter_50', 'ew_gesamt_50_bis_unter_60', 'ew_gesamt_60_bis_unter_70', 'ew_gesamt_70_bis_unter_80', 'ew_gesamt_80_und_aelter']}
                            ],
                responseProcessType: enums.response_process_type_2DimensionAgg_FlatPeriodic
            }
        },
        {
            indexName: 'shape_data_kaiserslautern_muncipality_regions',
            dataFor: enums.ESIndex_dataFor_muncipality_map,
        },
    ],
};
