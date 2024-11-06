//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//* Controller.js => _landUseVisualGenerate()

        // Get OSM data info from the records fetched
        // this.m_osmSearchModel.getTagsByGeoLocation({tag: 'nwr'}, plotCoordinates, record[geo_shapeKey].type, invertLngLat).then(resp => {
        //     console.log('OverpassAPI OSM: ');
        //     console.log(resp.elements);
        //     const nodes = {};
        //     resp.elements.filter(element => element.type === 'node').forEach(node => {
        //         nodes[node.id] = [node.lon, node.lat];
        //     });

        //     const ways = resp.elements.filter(element => element.type === 'way' && element.nodes[0] === element.nodes[element.nodes.length-1] && element.tags);
        //     const dataVis = {
        //     };

        //     const tagsToExtract = ['landuse', 'building', 'amenity', 'leisure', 'residential', 'highway', 'natural', 'waterway', 'power', 'other'];

        //     ways.forEach(way => {
        //         const points = way.nodes.map(nodeId => nodes[nodeId]);
        //         way['points'] = points;
        //         const polygon = turf.polygon([points]);
        //         way['area_size'] = round(turf.area(polygon) * 0.000247105381, 2);
        //         const tagKeys = intersection(Object.keys(way.tags), tagsToExtract);
        //         if (tagKeys.length === 0)
        //             console.log('Empty tags: ' + Object.keys(way.tags));
        //         tagKeys.forEach(tagKey => {
        //             if (!dataVis[way.tags[tagKey]])
        //                 dataVis[way.tags[tagKey]] = 0;
        //             dataVis[way.tags[tagKey]] = ( isNaN(way.tags[tagKey]) ? 0 : dataVis[way.tags[tagKey]] ) + way['area_size'];
        //         });

        //         this.m_mapModel.plotPolygon({plot: {coordinates: [points], type: 'Polygon'}}, 'plot', true);
        //     });

        //     const arr = []; Object.keys(dataVis).map((key) => arr.push({name: key, key: key, value: dataVis[key], color: 'black'}));
        //     this.m_landuseBars.reCreateProgressBars(arr, totalAreaSize);


        //     // const relations = resp.elements.filter(element => element.type === 'relation' && element.tags.boundary);
        //     // relations.forEach(relation => {
        //     //     relation.members.forEach(relationMember => {
        //     //         switch(relationMember.type) {
        //     //             case 'way': const wayInfo = resp.elements.filter(element => element.id === relationMember.ref);
        //     //                         if (wayInfo && wayInfo[0]) {
        //     //                             const points = wayInfo[0].nodes.map(nodeId => nodes[nodeId]);
        //     //                             wayInfo['points'] = points;
        //     //                             this.m_mapModel.plotPolygon({plot: {coordinates: [points], type: 'Polygon'}}, 'plot', true);
        //     //                         }
        //     //         }
        //     //     });
        //     // });

        //     // Replace the node IDs in the way with their [lat, lng] values

        //     // const way = resp.elements.find(element => element.type === 'way');
        //     // const points = way.nodes.map(nodeId => nodes[nodeId]);

        //     // Log the result
        //     // console.log(points);

        //     // const landuseGroups = groupBy(ways, function(obj) {
        //     //     return obj.tags.landuse;
        //     // });
        //     // console.log(landuseGroups);
        //     // const data = [];
        // });
//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//* Controller.js => _landUseVisualGenerate()
//* Once the data from the index is received for shapes within a polygon, we can firthur filter out shapes which have smaller shapes within them
//* This will avoid overlapping shapes and allow for visualisation of only on smallest shapes

        // // Define a function to check if a shape contains any smaller shapes
            // function containsSmallerShapes(shape) {
            //     // Get the bounds of the shape
            //     const shapeBounds = L.geoJSON(shape._source.geolocation).getBounds();

            //     // Check if any other shape's bounds are completely contained within this shape's bounds
            //     const hasContainedShapes = ways.some(otherShape => {
            //         if (shape === otherShape) {
            //         return false; // Skip self-comparison
            //         }
            //         const otherShapeBounds = L.geoJSON(otherShape._source.geolocation).getBounds();
            //         return shapeBounds.contains(otherShapeBounds);
            //     });

            //     return hasContainedShapes;
            // }

            // // Define a function to check if a shape contains any smaller shapes
            // function containsSmallerShapesTurf(shape) {
            //     // Check if any other shape's bounds are completely contained within this shape's bounds
            //     const hasContainedShapes = ways.some(otherShape => {
            //         if (shape === otherShape) {
            //             return false; // Skip self-comparison
            //         }
            //         const shape1 = turf.polygon(shape._source.geolocation.coordinates);
            //         const shape2 = turf.polygon(otherShape._source.geolocation.coordinates)
            //         // Calculate the intersection of the two shapes using Turf.js
            //         const intersection = turf.intersect(shape1, shape2);
            //         // Calculate the area of the intersection
            //         const intersectionArea = intersection ? turf.area(intersection) : 0;

            //         // Calculate the areas of the two shapes
            //         const shape1Area = turf.area(shape1);
            //         const shape2Area = turf.area(shape2);

            //         // Calculate the percentage of shape1 that is intersected by shape2
            //         const intersectionPercentage1 = intersectionArea / shape1Area * 100;

            //         // Calculate the percentage of shape2 that is intersected by shape1
            //         const intersectionPercentage2 = intersectionArea / shape2Area * 100;
            //         return ((intersectionPercentage2 > 90) && (shape1 > shape2))
            //     });

            //     return hasContainedShapes;
            // }
            // // Filter out shapes that contain smaller shapes
            // const filteredShapes = ways.filter(shape => !containsSmallerShapesTurf(shape));
//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//* MapModel.js
//* filter all the building and shapes based on the muncipality shape selected and if they lie within it
//* This function can be used when the shapes already exists on an overlay layer on the map
 
        // test(shape) {
        //     const shapeBounds = L.polygon(L.GeoJSON.coordsToLatLngs(shape, 1, L.GeoJSON.coordsToLatLng)).getBounds();
        //     const poly1 = L.polygon(shape[0]);

        //     this.overlayLayers['KL_landuse'].eachLayer(function(layer) {
        //         // Check if the layer's bounds intersect with the boundary polygon shape
        //         if (layer instanceof L.Polygon) {
        //             const otherShapeBounds = (layer).getBounds();

        //             const poly2 = L.polygon(layer.toGeoJSON().geometry.coordinates[0][0]);

        //             // if (shape.intersects(layer.getBounds())) {
        //             if (shapeBounds.contains(otherShapeBounds)) {
        //             // if (poly1.contains(poly2)) {
        //               // If the layer intersects with the boundary, show it
        //               layer.setStyle({opacity: 1});
        //             } else {
        //               // If the layer does not intersect with the boundary, hide it
        //               layer.setStyle({opacity: 0});
        //             }
        //         }
        //       });
        // };
//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//* Controller.js => _landUseVisualGenerate()
//* Previous function called before generic function implemented for querying shape data in a region
        
        // this.m_elasticsearchModel.queryAllDimensionsForIndex1('testscriptdata_openstreetmap', record[geo_shapeKey].coordinates).then(resp => {
        //     console.log('Elasticsearch: ');
        //     console.log(resp);

        //     const dataVis = {};

        //     const OSMTagPropertiesConfig = config.mapPlotConfig.on_geoShapeKeyClick.OSMTagsProperties
        //     const tagsToExtract = Object.keys(OSMTagPropertiesConfig);

        //     const ways = resp.filter(element => element._id.indexOf('way') > -1 && element._source.geolocation.type === 'Polygon');            

        //     ways.forEach(way => {
        //         const polygon = turf.polygon([way._source.geolocation.coordinates[0]]);
        //         way['area_size'] = this.#_convertShapeSizeToMetric(turf.area(polygon)); // round(turf.area(polygon) * 0.000247105381, 2);
        //         const tagKeys = intersection(Object.keys(way._source), tagsToExtract);
        //         if (tagKeys.length === 0)
        //             console.log('Empty tags: ' + Object.keys(way._source));
        //         else {
        //             tagKeys.forEach(tagKey => {
        //                 if ((dataVis[way._source[tagKey]] && dataVis[way._source[tagKey]].value) === undefined)
        //                     dataVis[way._source[tagKey]] = {value: 0};
        //                 dataVis[way._source[tagKey]] = { value: ( isNaN(dataVis[way._source[tagKey]].value) ? 0 : dataVis[way._source[tagKey]].value ) + way['area_size'], color: OSMTagPropertiesConfig[tagKey].color };
        //             });
    
        //             this.m_mapModel.plotPolygon({plot: {coordinates: [way._source.geolocation.coordinates[0]], type: 'Polygon'}}, 'plot', true, { color: (OSMTagPropertiesConfig[tagKeys[0]].color) ? OSMTagPropertiesConfig[tagKeys[0]].color : 'grey' }, 'KL_landuse');    
        //         }
        //     });

        //     const arr = [];
        //     Object.keys(dataVis).map((key) => arr.push({name: key, key: key, value: dataVis[key].value, color: dataVis[key].color}));
        //     this.m_landuseBars.reCreateProgressBars(arr, totalAreaSize);
        // });
//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
