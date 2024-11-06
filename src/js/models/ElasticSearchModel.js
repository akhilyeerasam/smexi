'use strict'
import jQuery from "jquery";
import { appSetting } from '../utilities/settings';
import { concat, assign } from 'lodash';
import { enums } from "../utilities/enums";

export class ElasticsearchModel {
    m_elasticsearchModelOptions;

    constructor(overwriteParameters) {
        // *** Private instance variables ***
        // all default settings go here. Can be overwritten.
        const defaults = {
            //proxyUrl: 'https://smexi.kl.dfki.de/SDGExplorerProxy.php',
            proxyUrl: null,
            elasticsearchBaseUrl: 'http://localhost:9200',
            elasticsearchIndex: '',
        };

        // Extend our default options with those provided.
        // Note that the first argument to extend is an empty
        // object – this is to keep from overriding our "defaults" object.

        // this.m_elasticsearchModelOptions = {...defaults, ...overwriteParameters.elasticsearchModel};
        this.m_elasticsearchModelOptions = defaults;
        // Make sure, base url ends with a slash
        if (this.m_elasticsearchModelOptions.elasticsearchBaseUrl.indexOf('/', this.m_elasticsearchModelOptions.elasticsearchBaseUrl.length - 1) === -1) {
            this.m_elasticsearchModelOptions.elasticsearchBaseUrl += '/';
        }
    };

    /******************************************************************************************************************************/
    // *** Public methods ***
    /******************************************************************************************************************************/
    getMappingOfIndex = () => {
        return new Promise((resolve, reject) => {
            const typeToGetMappingFor = '_doc';

            const me = this;

            const ajaxCallParameters = {
                dataType: 'json',
                type: 'get',
                success: function (data, textStatus, jqXHR) {
                    if ( data.error ) {
                        reject( {"message": "Found error (" + data.status + ") in Elasticsearch response of type " + data.error.type +": " + data.error.reason} );
                    } else {
                        try {
                            if (data) {
                                if (
                                    data[me.m_elasticsearchModelOptions.elasticsearchIndex] &&
                                    data[me.m_elasticsearchModelOptions.elasticsearchIndex].mappings &&
                                    data[me.m_elasticsearchModelOptions.elasticsearchIndex].mappings[typeToGetMappingFor] &&
                                    data[me.m_elasticsearchModelOptions.elasticsearchIndex].mappings[typeToGetMappingFor].properties
                                ) {
                                    // ES6

                                    const theMapping = data[me.m_elasticsearchModelOptions.elasticsearchIndex].mappings[typeToGetMappingFor].properties;
                                    resolve(theMapping);
                                } else if (
                                    data[me.m_elasticsearchModelOptions.elasticsearchIndex] &&
                                    data[me.m_elasticsearchModelOptions.elasticsearchIndex].mappings &&
                                    data[me.m_elasticsearchModelOptions.elasticsearchIndex].mappings.properties
                                ) {
                                    // ES7
                                    const theMapping = data[me.m_elasticsearchModelOptions.elasticsearchIndex].mappings.properties;
                                    resolve(theMapping);
                                } else {
                                    console.error('Mapping could not be found');
                                    reject( {"message": "Mapping could not be found"} );
                                }
                            }
                        } catch (err) {
                            const errorMessage = err.stack ? err.stack : err.message;
                            console.warn('Error when processing a successful ajax call: ' + errorMessage);
                            reject( {"message": 'Error when processing a successful ajax call: ' + errorMessage} );
                        }
                    }
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    //console.warn("AJAX call '" + urlToUse + "' failed! Request data was ", data);
                    console.warn('Error while trying to get the mapping of index ' + this.m_elasticsearchModelOptions.elasticsearchIndex + ' via ajax: ' + errorThrown);
                    // do nothing
                    reject( {"message": 'Error while trying to get the mapping of index ' + this.m_elasticsearchModelOptions.elasticsearchIndex + ' via ajax: ' + errorThrown} );
                },
            };

            // Add index name, index action and data field
            this.adjustFurtherAjaxCallParameters(ajaxCallParameters, this.m_elasticsearchModelOptions.elasticsearchIndex, '_mapping', '{}', 'get');
            jQuery.ajax(ajaxCallParameters);
        });
    };

    /**
     * 
     * @param {{}} requestData                  elasticSearch query for data request
     * @param {string} searchIndexName          elasticSearch index name
     * @param {{responseProcessType: string}} options   OPTIONAL object which will be used for processing the response to an appropriate format if needed
     * @returns 
     */
    executeSearchWithRequestData = (requestData, searchIndexName, options) => {
        const me = this;
        return new Promise((resolve, reject) => {
            const indexName = searchIndexName ? searchIndexName : me.m_elasticsearchModelOptions.elasticsearchIndex;
            const action = '_search';

            const ajaxCallParameters = {
                dataType: 'json',
                type: 'post',
                success: function (data, textStatus, jqXHR) {
                    if ( data.error ) {
                        reject( {"message": "Found error (" + data.status + ") in Elasticsearch response of type " + data.error.type +": " + data.error.reason} );
                    }
                    else {
                        try {
                            resolve( me._processSearchResponseData(data, options) );
                        } catch ( err ) {
                            const errorMessage = err.stack ? err.stack : err.message;
                            console.warn( 'Error when processing a successful ajax call: ' + errorMessage );
                            reject( {"message": err} );
                        }
                    }
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    console.warn("AJAX call using index '" + indexName + "' and action '" + action + "' failed! Request data was ", requestData);
                    console.warn('Error while trying to get data via ajax: ' + errorThrown);
                    reject( {"message": "Error in ajax call: " + JSON.stringify(textStatus) } );
                    // do nothing
                },
            };

            // Add url and data field
            this.adjustFurtherAjaxCallParameters(ajaxCallParameters, indexName, action, JSON.stringify(requestData));

            jQuery.ajax(ajaxCallParameters);
        });
    };

    queryAllDimensionsForIndex = (indexName, size) => {
        const me = this;
        const requestData = {
            size: size ? size : appSetting.elasticsearchQuerySize,
            query : {
                match_all : {}
            }
        };
        return new Promise((resolve, reject) => {
            const action = '_search';
            const ajaxCallParameters = {
                dataType: 'json',
                type: 'post',
                success: function (data, textStatus, jqXHR) {
                    if ( data.error ) {
                        reject( {"message": "Found error (" + data.status + ") in Elasticsearch response of type " + data.error.type +": " + data.error.reason} );
                    }
                    else {
                        try {
                            resolve( data.hits.hits ); // return only the array of index docs, other metadata is ignored for this query
                        } catch ( err ) {
                            const errorMessage = err.stack ? err.stack : err.message;
                            console.warn( 'Error when processing a successful ajax call: ' + errorMessage );
                            reject( {"message": err} );
                        }
                    }
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    console.warn("AJAX call using index '" + indexName + "' and action '" + action + "' failed! Request data was ", requestData);
                    console.warn('Error while trying to get data via ajax: ' + errorThrown);
                    reject( {"message": "Error in ajax call: " + JSON.stringify(textStatus) } );
                },
            };

            // Add url and data field
            this.adjustFurtherAjaxCallParameters(ajaxCallParameters, indexName, action, JSON.stringify(requestData));

            jQuery.ajax(ajaxCallParameters);
        });
    };

    async retrieveAllDocuments(index) {
        const docs = [];
        let scrollId;
      
        // Send initial search request to start scrolling
        const searchResponse = await fetch(`http://localhost:9200/${index}/_search?scroll=1m&size=10000`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            query: {
              match_all: {}
            }
          })
        });
      
        // Parse the response body and get the initial scroll id
        const { hits, _scroll_id } = await searchResponse.json();
        docs.push(...hits.hits);
        scrollId = _scroll_id;
      
        // Keep retrieving subsequent pages until all documents are retrieved
        while (true) {
          const scrollResponse = await fetch('http://localhost:9200/_search/scroll', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              scroll: '1m',
              scroll_id: scrollId
            })
          });
      
          const { hits, _scroll_id } = await scrollResponse.json();
      
          if (hits.hits.length === 0) {
            break;
          }
      
          docs.push(...hits.hits);
          scrollId = _scroll_id || scrollId;
      
          // If scroll_id is not returned, it means the scroll context has expired,
          // and we need to start a new search request to get a new scroll id
          if (!scrollId) {
            const searchResponse = await fetch(`http://localhost:9200/${index}/_search?scroll=1m&size=10000`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({
                query: {
                  match_all: {}
                }
              })
            });
      
            // Parse the response body and get the new scroll id
            const { hits, _scroll_id } = await searchResponse.json();
            docs.push(...hits.hits);
            scrollId = _scroll_id;
          }
        }
      
        return docs;
      }      

    /******************************************************************************************************************************/
    // *** Private methods ***
    /******************************************************************************************************************************/
    
    //*************************************************************************************************
    /**
     * Adjust some parameters for an ajax call, especially url and data field. If not using an (internal) proxy
     * additionally fields contentType and processData have to be adjusted
     *
     * @param ajaxCallParameters     the structure to be extended
     * @param indexName              the name of the index to use
     * @param indexAction            the action to be executed on the index
     * @param stringifiedParameters  the elasticsearch parameters as string
     * @param optionalRequestType    the request type: get or post
     * @param optionalPathParameter  an additional path parameter to be added to the url (needed e.g. for _update actions
     *                               or _cat)
     * @param optionalScrollValue    an additional scroll parameter to be added to the url's query part. Added is
     *                               ?scroll=<optionalScrollValue> (sample values are '1m' for 1 minute.
     *                               See Elasticsearch doc for more info)
     */
    adjustFurtherAjaxCallParameters(ajaxCallParameters, indexName, indexAction, stringifiedParameters, optionalRequestType, optionalPathParameter, optionalScrollValue, optionalScrollId ) {
        // In general requests to elasticsearch are sent via POST
        const requestType = optionalRequestType ? optionalRequestType : "post";
        const pathSuffix = optionalPathParameter ? "/"+optionalPathParameter : "";
        if (this.m_elasticsearchModelOptions.proxyUrl) {
            ajaxCallParameters.url = this.m_elasticsearchModelOptions.proxyUrl;
            ajaxCallParameters.data = {
                indexName: indexName,
                indexAction: indexAction
            };
            if ( optionalPathParameter !== null && optionalPathParameter !== undefined ) {
                ajaxCallParameters.data.additionalPath = optionalPathParameter;
            }
            if ( optionalScrollValue !== null && optionalScrollValue !== undefined ) {
                ajaxCallParameters.data.scrollValue = optionalScrollValue;
            }
            if ( optionalScrollId !== null && optionalScrollId !== undefined ) {
                ajaxCallParameters.data.scrollId = optionalScrollId;
            }
            if ( stringifiedParameters !== null && stringifiedParameters !== undefined ) {
                ajaxCallParameters.data.dataForRemote = stringifiedParameters;
            }
            ajaxCallParameters.data['requestType'] = requestType;
            ajaxCallParameters.dataType = 'json'; // Tell ajax, we expect a json object to be returned (in some cases we simply received a string)
            // this doesn't work: ajaxCallParameters.contentType = 'application/json; charset=UTF-8';
        } else {
            let finalUrl;
            if ( indexName ) {
                finalUrl = this.m_elasticsearchModelOptions.elasticsearchBaseUrl + indexName + '/' + indexAction + pathSuffix;
            }
            else {
                // Some actions (e.g. scrolling or _cat) might not use an index name
                finalUrl = this.m_elasticsearchModelOptions.elasticsearchBaseUrl + indexAction + pathSuffix;
            }
            if ( optionalScrollValue ) {
                finalUrl += "?scroll=" + optionalScrollValue;
            }
            if (optionalScrollId) {
                finalUrl += "&scroll_id=" + optionalScrollId;
            }

            ajaxCallParameters.url = finalUrl;
            //ajaxCallParameters.contentType = 'application/x-www-form-urlencoded; charset=UTF-8';
            ajaxCallParameters.contentType = 'application/json; charset=UTF-8';
            if (requestType !== 'get' && stringifiedParameters !== null && stringifiedParameters !== undefined) {
                ajaxCallParameters.data = stringifiedParameters;
            }
            //ajaxCallParameters.processData = false;
        }
    };

    _getNumberOfTotalHits (hitsObject) {
        let numberOfTotalResults;

        if (hitsObject.total && hitsObject.total.value) {
            // Since Elasticsearch 7 hitsObject.total is an object
            //alert( "Total value is a structure, obviously service is ES 7" );
            numberOfTotalResults = hitsObject.total.value;
        } else {
            // Before Elasticsearch 7 hitsObject.total is an integer
            //alert( "Total value is not a structure, obviously service is ES 6" );
            numberOfTotalResults = hitsObject.total;
        }
        return numberOfTotalResults;
    };

    _generateSearchRequestData(size) {
        const requestData = {
            size: size ? size : appSetting.elasticsearchQuerySize,
            query : {
                // match_all : {}
            }
        };
        return requestData;
    };

    /**
     * Add filters to requestData object and return it
     *
     * @param requestData            structure to which filter is to be added, filters will be added to this structure and returned back to parent calling function
     * @param filterQueryType        elasticSearchQueryType <bool/boosting/dis_max..>
     * @param filterQueryClause      query clause value <must/filter/should/must_not>
     * @param filterQueryProperties  array of the elasticsearch parameters as string. 
     *                               'geoFilter': optional key to be used only when dimensionType is 'geo_shape'
     *                               [ { dimension: <dimensionName>, dimensionType: <elasticSearch_dimensionType>, value: <filter_value>, geoFilter: { type: <polygon/envelope...>, relation: <within/contains...> }  } ]
     */
    _generateFilterQuery(requestData, filterQueryType, filterQueryClause, filterQueryProperties) {
        if (!requestData[filterQueryType]) {
            requestData[filterQueryType] = {};
        }

        if (!requestData[filterQueryType][filterQueryClause]) {
            requestData[filterQueryType][filterQueryClause] = [];
        }

        filterQueryProperties.forEach(filterQueryProp => {
            switch(filterQueryProp.dimensionType) {
                case 'geo_shape':   const geoFilterQuery = { 
                                                            geo_shape: {
                                                                [filterQueryProp.dimension]: {
                                                                    shape: {
                                                                        type: filterQueryProp.geoFilter.type, 
                                                                        coordinates: filterQueryProp.value 
                                                                    }, 
                                                                    relation: filterQueryProp.geoFilter.relation
                                                                }
                                                            }
                                                        };
                                    requestData[filterQueryType][filterQueryClause].push(geoFilterQuery);
                                    break;
                case 'keyword': const keywordFilterQuery = { term: { [filterQueryProp.dimension]: filterQueryProp.value } };
                                requestData[filterQueryType][filterQueryClause].push(keywordFilterQuery);
                                break;
                case 'exists':  const existsFilterQuery = {
                                    exists: { field: filterQueryProp.dimension }
                                };
                                requestData[filterQueryType][filterQueryClause].push(existsFilterQuery);
                                break;
                default: break;
            }
        });

        return requestData;
    }

    /**
     * Recurssive function which generates the aggregation query structure for elasticSearch
     * 
     * @param {{}} requestData                                              aggregation structure is stored in this object
     * @param {[{fieldName: string, size: number}]} dimensionsProperties    Array of objects, the order of the dimensions is critical!
     * @param {number} dimensionIndex                                       Aggregation index, which determins which substructure, the dimension represents. The recursive nature of this function is possible from this dimension
     * @returns 
     */
    _generateAggregateQuery(requestData, dimensionsProperties, dimensionIndex) {
        dimensionIndex = dimensionIndex ? dimensionIndex : 0;

        if(!requestData.aggregations) {
            requestData.aggregations = {
                ['dimension' + (dimensionIndex)]: {
                    terms: {
                        field: dimensionsProperties[dimensionIndex].fieldName,
                        size: dimensionsProperties[dimensionIndex].size ? dimensionsProperties[dimensionIndex].size : 10000
                    }
                }
            };

            if (dimensionsProperties[dimensionIndex].top_hits && (dimensionIndex === (dimensionsProperties.length - 1))) {
                requestData.aggregations['dimension' + (dimensionIndex)].aggregations = {
                    top_aggregation_hits: {
                        top_hits: {
                            size: 100,
                            _source: {
                                includes: dimensionsProperties[dimensionIndex].top_hits
                            }
                        }
                    }
                }
            }
        } else {
            alert('error');
        }

        if (dimensionIndex < dimensionsProperties.length - 1) {
            this._generateAggregateQuery(requestData.aggregations['dimension' + dimensionIndex], dimensionsProperties, (dimensionIndex + 1));
        }

        return requestData;
    };

    /**
     * Process the response data recieved from elasticSearch. Based on the search type 'Nested', 'Aggregation'... this function will allow maintainance of symmetry
     * 
     * @param {{}} responseData                 elasticSearch response from query
     * @param {{responseProcessType: string}} options   object, which can store all metadata required for processing the response
     * @returns 
     */
    _processSearchResponseData(responseData, options) {
        const responseProcessType = (options && options.responseProcessType) ? options.responseProcessType : undefined;
        switch(responseProcessType) {
            case enums.response_process_type_2DimensionAgg_Flat:    if (!(options.indexName && options.flatAggregationKey)) {
                                                                        return new Error('Incorrect options object for processing response data for type :-  FlatAggregation!');
                                                                    }
                                                                    const flatStructure = responseData.aggregations['dimension0'].buckets.map(record => {
                                                                        const obj = {[options.flatAggregationKey]: record.key};
                                                                        record['dimension1'].buckets.forEach(dim2Obj => {
                                                                            if (dim2Obj.top_aggregation_hits && dim2Obj.top_aggregation_hits.hits && dim2Obj.top_aggregation_hits.hits.hits) {
                                                                                obj[dim2Obj.key] = [];
                                                                                dim2Obj.top_aggregation_hits.hits.hits.forEach(hit_record => {
                                                                                    obj[dim2Obj.key].push(hit_record._source);
                                                                                })
                                                                            } else {
                                                                                obj[dim2Obj.key] = dim2Obj.doc_count;
                                                                            }
                                                                        });
                                                                        return { '_index': options.indexName, '_source': obj };
                                                                    });
                                                                    return flatStructure;
            case enums.response_process_type_2DimensionAgg_FlatPeriodic:    if (!(options.indexName && options.flatAggregationKey && options.periodKey)) {
                                                                                return new Error('Incorrect options object for processing response data for type :-  2DimensionAgg_FlatPeriodic!');
                                                                            }
                                                                            const flatPeriodicStructure = responseData.aggregations['dimension0'].buckets.map(record => {
                                                                                const obj = {[options.flatAggregationKey]: record.key, [options.periodKey]: {}};
                                                                                record['dimension1'].buckets.forEach(dim2Obj => {
                                                                                    if (dim2Obj.top_aggregation_hits && dim2Obj.top_aggregation_hits.hits && dim2Obj.top_aggregation_hits.hits.hits) {
                                                                                        dim2Obj.top_aggregation_hits.hits.hits.forEach(hit_record => {
                                                                                            obj[options.periodKey][dim2Obj.key] = hit_record._source;
                                                                                        });
                                                                                    }
                                                                                });
                                                                                return { '_index': options.indexName, '_source': obj };
                                                                            });
                                                                            return flatPeriodicStructure;
            default: return responseData;
        }
    }

}

