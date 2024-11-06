import { replace } from "lodash";
import { enums } from "../utilities/enums";

export class OSMSearchModel {
    constructor() {}

    /******************************************************************************************************************************/
    // *** Public methods ***
    /******************************************************************************************************************************/

    /**
     * 
     * @param OSMTags                   [{ tag: <>, key: <>, value: <> }] -> Refer the OSM documentation for acceptable inputs for these keys
     * @param searchCoordinates         coordinates to be queried upon
     * @param searchCoordinateType      <Polygon, Point...>
     * @param invertLngLat              Boolean value which inverts default coordinates in a LngLat format to LatLng format
     * @param expandRelation            Boolean value when true, also queries for the node and way information a relation requires. This avoids having to query for each member(node, way) info of a relation
     */
    getTagsByGeoLocation = (OSMTags, searchCoordinates, searchCoordinateType, invertLngLat, expandRelation) => {
        const query = this._buildOSMQueryParameters(OSMTags, searchCoordinates, searchCoordinateType, invertLngLat, expandRelation);

        return new Promise((resolve, reject) => {
            fetch(`https://overpass-api.de/api/interpreter?data=${encodeURIComponent(query)}`)
            .then(response => response.json())
            .then(data => {
                resolve(this._processOSMQueryResponse(data));
            })
            .catch(error => {
                console.error(error);
                reject(error);
            });
        });
    };

    /******************************************************************************************************************************/
    // *** Private methods ***
    /******************************************************************************************************************************/

    /**
     * Adjust some parameters for an ajax call, especially url and data field. If not using an (internal) proxy
     * additionally fields contentType and processData have to be adjusted
     *
     * @param OSMTags                   [{ tag: <>, key: <>, value: <> }] -> Refer the OSM documentation for acceptable inputs for these keys
     * @param searchCoordinates         coordinates to be queried upon
     * @param searchCoordinateType      <Polygon, Point...>
     * @param invertLngLat              Boolean value which inverts default coordinates in a LngLat format to LatLng format
     * @param expandRelation            Boolean value when true, also queries for the node and way information a relation requires. This avoids having to query for each member(node, way) info of a relation
     */
    _buildOSMQueryParameters(OSMTags, searchCoordinates, searchCoordinateType, invertLngLat, expandRelation) {
        let query = `[out:json];`;

        OSMTags.forEach(OSMTag => {
            query += `${OSMTag.tag}${OSMTag.key ? `["${OSMTag.key}"${OSMTag.value ? `="${OSMTag.value}"` : ''}]` : ''}`;
            switch(searchCoordinateType) {
                case 'Polygon': let polygonQueryString;
                                if (invertLngLat)
                                    polygonQueryString = searchCoordinates[0].toString().replaceAll('LatLng','').replaceAll('(','').replaceAll(')','').replaceAll(",", " ");
                                else
                                    polygonQueryString = searchCoordinates[0].toString().replaceAll(",", " ");

                                if (expandRelation || OSMTag.tag === 'nwr') {
                                    query += `(poly:"${polygonQueryString}")->.ways;
                                    node(w)->.nodes;
                                    way(pivot.ways)->.waysnodes;
                                    (.ways; .nodes; .waysnodes;);
                                    out body;
                                    >;
                                    out skel qt;`;
                                } else {
                                    query += `(poly:"${polygonQueryString}");
                                    out;`;
                                }
                                
                                break;
                default: break;
            }
        });

        return query;
    };

    /**
     * Process the OSMQuery response data, so it can be used in our application without constantly requiring to process the data structure in a fashion similar to the rest of the code
     * For example, plotting shapes on the map, becomes easier with this processing
     * @param {*} data Response data from the query
     */
    _processOSMQueryResponse(data) {
        const nodes = data.elements.filter(result => result.type === 'node');
        const ways = data.elements.filter(result => result.type === 'way');
        const relations = data.elements.filter(result => result.type === 'relation');

        const referencedNodes = []; // Array which keeps track of nodes which are used as references for ways/relations only. So they can be excluded from the final dataset to avoid redudant data
        const referencedWays = [];  // Similarly as 'referencedNodes', but for the context of ways

        nodes.forEach(node => {
            node[enums.osm_geoShapeKey] = { 'coordinates': [node.lat, node.lon] };
        });

        // The nodeMap will help replace the nodeIds in a way in the correct order which is required for drawing shapes correctly
        const nodeMap = new Map(nodes.map(node => [node.id, node[enums.osm_geoShapeKey]['coordinates']]));

        ways.forEach(way => {
            const way_nodes_coordinates = way.nodes.map(nodeId => {
                referencedNodes.push(nodeId);
                return nodeMap.get(nodeId)
            });
            way[enums.osm_geoShapeKey] = { 'coordinates': way_nodes_coordinates };
        });

        // The wayMap will help replace the wayRefs in a relation in the correct order which is required for drawing shapes correctly
        const wayMap = new Map(ways.map(way => [way.id, way[enums.osm_geoShapeKey]['coordinates']]));

        relations.forEach(relation => {
            const relation_ways = relation.members.map(way => {
                referencedWays.push(way.ref);
                return wayMap.get(way.ref)
            });
            relation[enums.osm_geoShapeKey] = { 'coordinates': relation_ways };
        });

        // Remove nodes/ways which were used only for reference purposes in a way/relation respectivly
        data.elements = data.elements.filter(result => !referencedNodes.includes(result.id) && !referencedWays.includes(result.id));

        return data;
    };
}
