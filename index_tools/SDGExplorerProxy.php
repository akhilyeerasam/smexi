<?PHP

// ############################################################################
//$valid_index_names = array( 'kaiserslautern_metadata_input', 'metadata_storage_datastructure' );
//$valid_actions = array( '_mapping', '_search' );
//$valid_actions = array( '_search', '_doc' );



function isValidCombination( $indexName, $indexAction, $requestType, $additionalPath ) {

    // Possible actions: '_doc','_search', '_update', '_refresh', '_pit'
    $validCombinations = array(
        // Name of every index
        'shape_data_kaiserslautern_statistical_regions'=>array('_search'=>array('POST', 'GET'), '_doc'=>array('GET'), '_mapping'=>array('GET')),
        'stat_bezirk_soziodemo_mv2022'=>array('_search'=>array('POST', 'GET'), '_doc'=>array('GET'), '_mapping'=>array('GET')),
        'kaiserslautern_kfz'=>array('_search'=>array('POST', 'GET'), '_doc'=>array('GET'), '_mapping'=>array('GET')),
        'aggregation_20230718_statistische_bezirke_ohne_asterisk'=>array('_search'=>array('POST', 'GET'), '_doc'=>array('GET'), '_mapping'=>array('GET')),
        'shape_data_kaiserslautern_muncipality_regions'=>array('_search'=>array('POST', 'GET'), '_doc'=>array('GET'), '_mapping'=>array('GET')),
        
        'NONE'=>array('_cat'=>array('GET'),'_search'=>array('POST', 'GET'), 'EMPTY'=>array('GET'))
        // Example to allow querying an index 
        //'<IndexName>'=>array('_search'=>array('POST', 'GET'), '_doc'=>array('GET'), '_mapping'=>array('GET')),        
        // To allow all indices to be queried for use below. WARNING: NOT RECOMMENDED!
        //'EVERY'=>array('_search'=>array('POST', 'GET'), '_doc'=>array('GET'), '_bulk'=>array('POST'), '_mapping'=>array('GET')),
    );
    $result = false;

    $actionToCheck = $indexAction === null ? "EMPTY" : $indexAction;

    if ( ! $indexName ) {
        $allowedGlobalActions = $validCombinations['NONE'];
        if ( array_key_exists( $actionToCheck , $allowedGlobalActions ) ) {
            $allowedRequestTypes = $allowedGlobalActions[$actionToCheck];
            if ( in_array( $requestType , $allowedRequestTypes ) ) {
                $result = true;
            }
        }
    }
    else {
        $forAllIndicesAllowed = $validCombinations['EVERY'];
        if ( array_key_exists( $actionToCheck , $forAllIndicesAllowed ) ) {
            $allowedRequestTypes = $forAllIndicesAllowed[$actionToCheck];
            // syslog( LOG_WARNING, var_dump($allowedRequestTypes) );
            // syslog( LOG_WARNING, "Huhu" );
            if ( in_array( $requestType , $allowedRequestTypes ) ) {
                $result = true;
            }
        }

        if ( ! $result ) {
            // No allowance yet. Maybe there is a special entry for this index?
            if( array_key_exists( $indexName, $validCombinations ) ) {
                $allowedActions = $validCombinations[$indexName];
                if ( in_array( $actionToCheck , $allowedActions ) ) {
                    $allowedRequestTypes = $allowedActions[$actionToCheck];
                    if ( in_array( $requestType , $allowedRequestTypes ) ) {
                        $result = true;
                    }
                }
            }
        }
    }

    // we could further restrict e.g. to only allow 'indices' as additional path for action '_cat'

    $safeName = $indexName ? $indexName : "<UNSPECIFIED>";
    //syslog( LOG_WARNING, "Is valid action: " . $safeName . " " . $actionToCheck. " (" . $result .")" );

    return( $result );
}


// ############################################################################
function isSafeIndexName( $indexName ) {
    // empty index name is allowed!
    return( !$indexName || preg_match( "/^[a-z_0-9]+$/", $indexName ) );
}

// ############################################################################
function getParameters() {

    $contentType = isset($_SERVER["CONTENT_TYPE"]) ? trim($_SERVER["CONTENT_TYPE"]) : '';
    syslog(LOG_WARNING, "Content type is " . $contentType );
    if ( stripos( $contentType, 'application/json' ) === 0 ) {
        // Content-Type header of the request starts with 'application/json'

        //Make sure that it is a POST request.
        if(strcasecmp($_SERVER['REQUEST_METHOD'], 'POST') != 0){
            throw new Exception('Request method must be POST!');
        }

        /*
        //Make sure that the content type of the POST request has been set to application/json
        $contentType = isset($_SERVER["CONTENT_TYPE"]) ? trim($_SERVER["CONTENT_TYPE"]) : '';
        if(strcasecmp($contentType, 'application/json') != 0){
            throw new Exception('Content type must be: application/json');
        }
        */

        //Receive the RAW post data.
        $content = trim(file_get_contents("php://input"));

        //Attempt to decode the incoming RAW post data from JSON.
        $decoded = json_decode($content, true, 100);

        //If json_decode failed, the JSON is invalid.
        if(!is_array($decoded)){
            throw new Exception('Received content contained invalid JSON!');
        }
        syslog(LOG_WARNING, "Decoded: " . print_r($decoded, true) );

        $indexName = isset($decoded["indexName"]) ? $decoded["indexName"] : null;
        $indexAction = isset($decoded["indexAction"]) ? $decoded["indexAction"] : null;
        $requestType = isset($decoded["requestType"]) ? $decoded["requestType"] : null;
        $additionalPath = isset($decoded["additionalPath"]) ? $decoded["additionalPath"] : null;
        $scrollValue = isset($decoded["scrollValue"]) ? $decoded["scrollValue"] : null;
        $prettyFlag = array_key_exists( "pretty", $decoded );
        if ( $indexAction && strcasecmp( $indexAction, "_bulk" ) === 0 && isset($decoded["dataForRemote"]) ) {
            syslog(LOG_WARNING, "Raw data for remote is '" . json_encode($decoded["dataForRemote"]) . "'" );
            // data for _bulk operations is sent as an array of strings. These must be concatenated for the use in Elasticsearch
            $dataForRemote = "";
            foreach ($decoded["dataForRemote"] as &$value) {
                $dataForRemote .= json_encode( $value ) . "\n";
                //syslog(LOG_WARNING, "One raw data for remote" );var_dump($value);
            }
            //$dataForRemote = implode( $decoded["dataForRemote"] );
        }
        else {
            $dataForRemote = isset($decoded["dataForRemote"]) ? json_encode($decoded["dataForRemote"]) : null;
        }
        syslog(LOG_WARNING, "Data for remote is '" . $dataForRemote . "'" );
        return array( $indexName, $indexAction, $dataForRemote, $requestType, $additionalPath, $scrollValue, $prettyFlag );
    }
    else {
        syslog( LOG_WARNING, "Note: content type is not 'application/json' but '" . $contentType . "'" );
        // Get the request parameters
        $indexName = isset($_REQUEST["indexName"]) ? $_REQUEST["indexName"] : null;
        $indexAction = isset($_REQUEST["indexAction"]) ? $_REQUEST["indexAction"] : null;
        $dataForRemote = isset($_REQUEST["dataForRemote"]) ? $_REQUEST["dataForRemote"] : null;
        $requestType = isset($_REQUEST["requestType"]) ? $_REQUEST["requestType"] : null;
        $additionalPath = isset($_REQUEST["additionalPath"]) ? $_REQUEST["additionalPath"] : null;
        $scrollValue = isset($_REQUEST["scrollValue"]) ? $_REQUEST["scrollValue"] : null;
        $prettyFlag = array_key_exists( "pretty", $_REQUEST );
        return array( $indexName, $indexAction, $dataForRemote, $requestType, $additionalPath, $scrollValue, $prettyFlag );
    }

}
// ############################################################################

function main() {

    list( $indexName, $indexAction, $dataForRemote, $requestType, $additionalPath, $scrollValue, $prettyFlag ) = getParameters();

    // Where to find the elasticsearch index
    $elasticsearchBaseUrl = 'http://localhost:9200';
    /*
    if ( !$indexAction ) {
        // Passed url not specified.
        //$contents = 'ERROR: index action not specified';
        $contents = "{ 'errorString': 'ERROR: index action not specified', 'status': 400 }";
        $status = array( 'http_code' => 'ERROR' );
        http_response_code(400);
    }
    */
    if ( !$requestType ) {
        // Request type not specified.
        $contents = "{ 'errorString': 'ERROR: request type not specified', 'status': 400 }";
        $status = array( 'http_code' => 'ERROR' );
        http_response_code(400);
    }
    else {
        $requestType = strtoupper( $requestType );
        $safeName = $indexName ? $indexName : "<UNSPECIFIED>";
        //syslog(LOG_WARNING, "Metadata proxy is called: " . $safeName . " " . $indexAction);
        if ( ! isValidCombination( $indexName, $indexAction, $requestType, $additionalPath ) ) {
            $myMessage = 'Access via action ' . $indexAction . ' to index ' . $safeName . ' via ' . $requestType . ' is not allowed';
            syslog(LOG_WARNING, $myMessage);
            $contents = "{ 'errorString': '" . $myMessage . "', 'status': 403 }";
            $status = array( 'http_code' => 'ERROR' );
            http_response_code(403);
        }
        else {

            // Note: indexAction is safe since only values occurring in "validCombinations" are accepted
            if ( ! isSafeIndexName( $indexName ) ) {
                $myMessage = 'Illegal index name ' . $safeName . ' specified';
                syslog(LOG_WARNING, $myMessage);
                $contents = "{ 'errorString': '" . $myMessage . "', 'status': 403 }";
                $status = array( 'http_code' => 'ERROR' );
                http_response_code(403);
            }
            else {

                if ( $indexName ) {
                    $url = $elasticsearchBaseUrl . "/" . $indexName;
                }
                else {
                    $url = $elasticsearchBaseUrl;
                }

                if ( $indexAction ) {
                    $url .= "/" . $indexAction;
                }
        
                if ( $additionalPath != null ) {
                    $url .= "/" . urlencode($additionalPath);
                }

                $queryParameters = "";
                if ( $scrollValue != null ) {
                    $url .= "?scroll=" . urlencode($scrollValue);
                    if ( $prettyFlag ) {
                        $queryParameters .= "&pretty";
                    }
                }
                else {
                    if ( $prettyFlag ) {
                        $queryParameters .= "?pretty";
                    }
                }

                $url .= $queryParameters;  // add query part (if any)

                $ch = curl_init( $url );

                if ( strtolower($requestType) != 'get' && $dataForRemote ) {
                    # Setup request to send json via POST.
                    curl_setopt( $ch, CURLOPT_POSTFIELDS, $dataForRemote );
                }
                curl_setopt( $ch, CURLOPT_HTTPHEADER, array('Content-Type:application/json; charset=UTF-8;', 'Access-Control-Allow-Origin: *'));

                curl_setopt( $ch, CURLOPT_FOLLOWLOCATION, true );
                // Note: if you set CURLOPT_HEADER to true, the headers will be added to the front of the content received
                curl_setopt( $ch, CURLOPT_HEADER, false );
                curl_setopt( $ch, CURLOPT_RETURNTRANSFER, true );

                $headers = [];
                // this function is called by curl for each header received
                curl_setopt($ch, CURLOPT_HEADERFUNCTION,
                            function($curl, $header) use (&$headers)
                            {
                                $len = strlen($header);
                                $header = explode(':', $header, 2);
                                if (count($header) < 2) // ignore invalid headers
                                    return $len;

                                $headers[strtolower(trim($header[0]))][] = trim($header[1]);

                                return $len;
                            }
                            );

                if ( isset( $_REQUEST['USER_AGENT'] ) ) {
                    curl_setopt( $ch, CURLOPT_USERAGENT, $_REQUEST['USER_AGENT'] );
                }
                else {
                    curl_setopt( $ch, CURLOPT_USERAGENT, $_SERVER['HTTP_USER_AGENT'] );
                }

                syslog(LOG_WARNING, "Will send request now: " . "url is " . $url . ", data for remote: " . substr($dataForRemote, 0, 250) . "..." );

                // Splitting on \r\n\r\n is not reliable when CURLOPT_FOLLOWLOCATION is on or when the server responds with a 100 code!!
                //list( $header, $contents ) = preg_split( '/([\r\n][\r\n])\\1/', curl_exec( $ch ), 2 );
                $contents = curl_exec($ch);

                //syslog(LOG_WARNING, "Got content: " . substr($contents, 0, 250) . "..." );

                $status = curl_getinfo( $ch );

                curl_close( $ch );
            }
        }
    }

    header('Content-Type: application/json; charset=UTF-8;');
    header('Access-Control-Allow-Origin: *');
    //header('access-control-allow-methods: POST,GET');
    //header('access-control-allow-headers: X-Requested-With,Content-Length,Content-Type');
    //header('access-control-allow-methods: POST,OPTIONS,DELETE,HEAD,PUT,GET');
    //header('access-control-max-age: 1728000');
    //header('allow: OPTIONS, TRACE, GET, HEAD, POST');

    //syslog(LOG_WARNING, "Will send response now: " . substr($contents, 0, 250) . "..." );
    print $contents;
}

main();

?>
