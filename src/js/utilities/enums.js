export const enums = Object.freeze({
    baselayer_default: 'Default',
    baselayer_transport: 'Transport Map',

    overlay_layer_KL_statistical_regions: "KL_statistical_regions",
    overlay_layer_KL_muncipality_regions: "KL_muncipality_regions",
    overlay_layer_KL_landuse: "KL_landuse",
    overlay_layer_KL_amenities: "KL_amenities",
    overlay_layer_KL_transport: "KL_transport",
    overlay_layer_selected_region: "KL_selected_region",
    overlay_legend_transport_routes: "transport_routes_legend",

    ESIndex_dataFor_statistical_map: "statistical_map",
    ESIndex_dataFor_muncipality_map: "muncipality_map",

    response_process_type_2DimensionAgg_Flat: "2DimensionAgg_Flat",
    response_process_type_2DimensionAgg_FlatPeriodic: "2DimensionAgg_FlatPeriodic",

    osm_geoShapeKey: 'osm_geoLocation', // Set as per the Elasticsearch index dimension in datasets referenced

    transportData_prefix_options: 'transportOptions_', // Prefix word to differentiate between datasets for each transportType 'travel option' in the transportData object in 'RegionInfoBarController' file
    transportData_prefix_platforms: 'transportPlatforms_', // Prefix word to differentiate between datasets for each transportType 'travel platform' in the transportData object in 'RegionInfoBarController' file

    // List of all fixed DOM Element Ids
    // NOTE: Ensure these values and the values in index.html file are the same! Some sections are not yet moved into a 'template'. Post moving to a template, there will only be 1 reference to these Ids
    region_info_bar_container_Id: "region_info_bar_container",
    compare_regions_button_Id: 'compare_regions',
    sdg_score_settings_button_Id: 'sdg_score_settings_button',
    map_container_Id: 'map_container',
    select_region_view_Id: 'select_region_view'
});
