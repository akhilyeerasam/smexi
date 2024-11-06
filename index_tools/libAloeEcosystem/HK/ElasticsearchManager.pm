package HK::ElasticsearchManager;

use strict;
use warnings;
use Carp;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case :config pass_through :config no_auto_abbrev);
use Data::Dumper;
#use Storable qw(dclone);

use Term::ReadKey;
use JSON::XS;
use LWP::UserAgent;

use HK::BaseUtils;

# To export only selected functions (or variables), we derive
# from class 'Exporter', so the user can call method 'import()'
# of class 'Exporter'
use Exporter;
our @ISA = ( 'Exporter' );
# which functions to export by default?
our @EXPORT = qw();
# which functions to export byuser request?
our @EXPORT_OK = qw();


#############################################################################################

# Constructor of class HK::ElasticsearchManager
sub new {
    my $class = shift;
    my $self  = {};

    bless ($self, $class);

    $self->{namespace} = "";
    $self->{dieOnError} = 1;
    $self->{beVerbose} = 0;
    my %options = @_;
    foreach my $optionKey ( keys %options ) {
	if ( $optionKey !~ m/^_/ ) {
	    $self->{$optionKey} = $options{$optionKey};
	    #print STDERR "Option key $optionKey is now " . $options{$optionKey} . "\n";
	}
    }

    return $self;
}

#############################################################################
sub getUsageString {
    my ( $self ) = @_;
    my $namespace =  $self->{namespace};
    my $errorString = <<"EOTEXT";
Elasticsearch manager options: [-h|--help] [--emVerbose${namespace}] [--elasticsearchErrorIsNotFatal${namespace}] [--elasticsearchUrl${namespace} <elasticsearchUrl>] [--elasticsearchDoNotVerifyHostname${namespace}] [--elasticsearchAccessToken${namespace} <token>] [--elasticsearchHttpTimeout${namespace} <seconds>] [--indexName${namespace} <indexName>] 

  Please note that specifying an elasticsearch url is mandatory.
  --elasticsearchDoNotVerifyHostname can be used to avoid hostname verification in SSL requests (that is: if the elasticsearch URL starts with https: try this in case of trouble)
  Use --elasticsearchAccessToken, if the elasticsearch index is using authentication.
  Default value for elasticsearchHttpTimeout is 180 seconds.

  Please note that you must switch to a specific index before sending HTTP requests via this manager

Sample parameters:
  --elasticsearchUrl${namespace} http://pc-4301:9200 --indexName${namespace} social_web_services
  --elasticsearchUrl${namespace} http://localhost:9200

EOTEXT
    return( $errorString );
}
#############################################################################

sub initFromCommandlineParameters {
    my $self = shift;
    my $commandLineArguments = shift;

    my $wasOkay = $self->checkCommandLine( $commandLineArguments );

    if ( $wasOkay ) {
	# Init default values (if any)
	$self->init();
    }
    return( $wasOkay );
}

#############################################################################
sub checkCommandLine {
    my ( $self, $arrayToCheck ) = @_;
    my $namespace =  $self->{namespace};

    my ( $elasticsearchUrl, $elasticsearchErrorIsNotFatal, $indexName );
    my ( $helpMe, $beVerbose, $doNotVerifyHostname, $accessToken, $httpTimeout );

    # Check command line
    if ( GetOptionsFromArray( $arrayToCheck,
			      "elasticsearchUrl${namespace}=s" => \$elasticsearchUrl,
			      "indexName${namespace}=s" => \$indexName,
			      "elasticsearchErrorIsNotFatal${namespace}" => \$elasticsearchErrorIsNotFatal,
			      "elasticsearchDoNotVerifyHostname${namespace}" => \$doNotVerifyHostname,
			      "elasticsearchAccessToken${namespace}=s" => \$accessToken,
			      "elasticsearchHttpTimeout${namespace}=i" => \$httpTimeout,
			      "emVerbose${namespace}" => \$beVerbose,
			      "h" => \$helpMe, "help" => \$helpMe ) ) {
	# okay
	if ( $helpMe ) {
	    # nothing else needed: don't check command line
	}
	else {
	    # HK: 01.02.2018: I think I dislike a default value for this
	    #$elasticsearchUrl = "http://localhost:9200" unless defined( $elasticsearchUrl );
	    if ( defined( $elasticsearchUrl ) ) {
		$elasticsearchUrl =~ s~/+$~~;  # ensure that the base url doesn't contain trailing slashes
	    }
	    else {
		$helpMe = 1;
	    }
	    $self->{elasticsearchUrl} = $elasticsearchUrl;
	    $self->{dieOnError} = not $elasticsearchErrorIsNotFatal;
	    $self->{beVerbose} = $beVerbose;
	    $self->{accessToken} = $accessToken if defined( $accessToken );

	    $self->{doNotVerifyHostname} = $doNotVerifyHostname;
	    $self->{httpTimeout} = $httpTimeout if defined( $httpTimeout );
	    
	    if ( defined( $indexName ) ) {
		$self->switchToIndex( $indexName );
		$self->{_disableFurtherIndexSwitching} = 1;
	    }
	}
    }
    else {
	$helpMe = 1;
    }

    #print Dumper( $self );

    if ( $helpMe ) {
	return( 0 );
    }
    else {
	return( 1 );
    }
}
#############################################################################################

sub init {
    my $self = shift;

    #$self->{_jsonCoder} = JSON::XS->new->ascii->pretty->allow_nonref;
    #$self->{_jsonCoder} = JSON::XS->new->utf8->pretty->allow_nonref;
    $self->{_jsonCoder} = JSON::XS->new->utf8->allow_nonref;
    $self->{_jsonDecoder} = JSON::XS->new->utf8->pretty->allow_nonref;
    my %config = ();
    $config{timeout} = $self->{httpTimeout} if $self->{httpTimeout};
    
    $self->{_userAgent} = LWP::UserAgent->new( %config );
    $self->{_userAgent}->ssl_opts( "verify_hostname" => 0 ) if $self->{doNotVerifyHostname};


    $self->{elasticsearchVersion} = $self->_getElasticsearchVersion();

}
#############################################################################################
sub _getElasticsearchVersion() {
    my ( $self ) = @_;
    my $url = $self->{elasticsearchUrl};
    my $info = $self->_sendRawHttpGetRequest( $url );
    my $versionNumber = $info->{version}->{number};
    # Sorry: of course you cannot turn 8.6.2 into a number easily. So we will return the version as string
    #return( HK::BaseUtils::convertStringToFloat( $versionNumber ) );
    return( $versionNumber );
}

#############################################################################################
sub getJsonCoder {
    my ( $self ) = @_;
    return( $self->{_jsonCoder} );
}

#############################################################################################
sub getElasticsearchUrl {
    my ( $self ) = @_;
    return( $self->{elasticsearchUrl} );
}
#############################################################################################
sub switchToIndex {
    my ( $self, $indexName ) = @_;
    if ( $self->{_disableFurtherIndexSwitching} ) {
	die "Index name was specified by user via commandline parameter. Thus further switching programmatically is disabled!!\n";
    }
    else {
	$indexName =~ s~/+$~~;  # ensure that the index name doesn't contain trailing slashes
	$self->{indexName} = $indexName;
    }
}
#############################################################################################
sub getCurrentIndex {
    my ( $self ) = @_;
    return( $self->{indexName} );
}
#############################################################################################
sub isIndexChosen {
    my ( $self ) = @_;
    return( defined( $self->{indexName} ) );
}

#############################################################################################
# Use this method to synchronize between writing and reading access. This is more or less flushing
# the content of an index after write access.
# Use after writing and before reading subsequently.
# Beware: there is a _flush in the elasticsearch api with different semantics
#
sub refresh {
    my ( $self ) = @_;

    $self->_ensureHttpRequestPossible;

    my $url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/_refresh";
    return( $self->_sendRawHttpGetRequest( $url ) );
}
#############################################################################################
sub sendHttpGetRequestAndIterateOnResult {
    my ( $self, $urlPostfix, $handlerToCall ) = @_;

    my( $wasOkay, $response ) = $self->sendHttpGetRequest( $urlPostfix );
    if ( $wasOkay ) {
	if ( exists( $response->{hits}->{hits} ) ) {
	    print STDERR "Number of hits is:" . @{ $response->{hits}->{hits} } . "\n" if $self->{beVerbose};
	    foreach my $entry ( @{ $response->{hits}->{hits} } ) {
		$handlerToCall->( $entry->{_source}, $entry->{_index}, $entry->{_type}, $entry->{_id}, $entry->{_score}, $entry->{_parent} );
	    }
	}
    }
}
#############################################################################################
# This may be used for aggregations or the like. The parameter '$pathToCollection' will tell, where we find the
# collection to be iterated on.
# Path to collection should be of the form '<path1>:<path2>:...:<pathN>'.
sub sendHttpPostRequestAndIterateOnResult {
    my ( $self, $urlPostfix, $body, $handlerToCall, $pathToCollection ) = @_;

    my( $wasOkay, $response, $responseString ) = $self->sendHttpPostRequest( $urlPostfix, $body );
    if ( $wasOkay ) {
        my @pathComponents = split( /:/, $pathToCollection );
        my $subStructure = $response;
        while( @pathComponents > 0 ) {
            my $current = shift( @pathComponents );
            if ( exists( $subStructure->{$current} ) ) {
                $subStructure = $subStructure->{$current};
            }
            else {
                confess( "Error in parameters. Path $pathToCollection does not exist\n" );
            }
        }

        foreach my $entry ( @$subStructure ) {
            $handlerToCall->( $entry );
        }
    }
}
#############################################################################################
# @@@Deprecated
#   Use sendHttpPostRequestAndIterateOnResultWithPaging instead!!
#
# $size may not exceed 10000
sub sendHttpSearchRequestAndIterateOnResultWithPaging {
    my ( $self, $size, $timeToKeep, $type, $handlerToCall ) = @_;

    $timeToKeep = "1m" unless defined( $timeToKeep );
    my $urlPostfixToUse = defined( $type ) ? $type : "";
    $urlPostfixToUse .= "/_search?size=$size&scroll=${timeToKeep}";   # For scrolling we need a scroll context
    my $finished = 0;
    my $lastUsedScrollId = undef;

    my $httpGetRequest = $urlPostfixToUse;
    print STDERR "Will send get request: $httpGetRequest\n" if $self->{beVerbose};
    my( $wasOkay, $response, $responseString ) = $self->sendHttpGetRequest( $httpGetRequest );
    do {
	#die Dumper( $response );
	if ( $wasOkay ) {
	    if ( exists( $response->{_scroll_id} ) ) {
		$lastUsedScrollId = $response->{_scroll_id};
		$httpGetRequest = $self->{elasticsearchUrl} . "/_search/scroll?scroll_id=${lastUsedScrollId}&scroll=${timeToKeep}";
	    }
	    else {
		$finished = 1;
	    }
	    
	    if ( exists( $response->{hits}->{hits} ) ) {
		if ( @{ $response->{hits}->{hits} } < $size ) {
		    $finished = 1;
		    $lastUsedScrollId = undef;
		}
		
		foreach my $entry ( @{ $response->{hits}->{hits} } ) {
		    $handlerToCall->( $entry->{_source}, $entry->{_index}, $entry->{_type}, $entry->{_id}, $entry->{_score}, $entry->{_parent} );
		}
	    }
	    else {
		warn "No hits found\n";
		$finished = 1;
	    }
	}
	else {
	    warn "Sending http request failed\n";
	    $finished = 1;
	}

	unless( $finished ) {
	    print STDERR "Will send raw get request: $httpGetRequest\n" if $self->{beVerbose};
	    ( $wasOkay, $response ) = $self->_sendRawHttpGetRequest( $httpGetRequest );
	}

    } while( ! $finished );


    if ( defined( $lastUsedScrollId ) ) {
	$self->_clearScrollApi( $lastUsedScrollId );
    }

    # curl -XDELETE localhost:9200/_search/scroll -d '{ "scroll_id" : ["c2Nhbjs2OzM0NDg1ODpzRlBLc0FXNlNyNm5JWUc1"] }'

}
#############################################################################################
# $size may not exceed 10000
# $timeToKeep should be of the form <count><unit>, e.g.: "30s" (30 seconds) or "1m" (1 minute)
#     Possible units: d Days, h Hours, m Minutes, s Seconds, ms Milliseconds, micros Microseconds, nanos Nanoseconds
# $body can be undefined, if you do not want to specify body content
# Please note that a simple search is expected to be executed and the iteration is done on result->{hits}->{hits}
sub sendHttpPostRequestAndIterateOnResultWithPaging {
    my ( $self, $size, $timeToKeep, $type, $body, $handlerToCall ) = @_;
    $timeToKeep = "1m" unless defined( $timeToKeep );

    my $followUpBody = { "scroll" => $timeToKeep, "scroll_id" => "" };

    my $urlPostfixToUse = defined( $type ) ? "${type}/" : "";
    $urlPostfixToUse .= "_search?size=${size}&scroll=${timeToKeep}";   # For scrolling we need a scroll context
    my $finished = 0;
    my $lastUsedScrollId = undef;

    my $httpGetRequest = $urlPostfixToUse;
    print STDERR "Will send post request: $httpGetRequest\n" if $self->{beVerbose};
    my( $wasOkay, $response, $responseString ) = $self->sendHttpPostRequest( $urlPostfixToUse, $body );
    do {
	#die Dumper( $response );
	if ( $wasOkay ) {
	    if ( exists( $response->{_scroll_id} ) ) {
		$lastUsedScrollId = $response->{_scroll_id};
		$followUpBody->{scroll_id} = $lastUsedScrollId;
	    }
	    else {
		$finished = 1;
	    }
	    
	    if ( exists( $response->{hits}->{hits} ) ) {
		if ( @{ $response->{hits}->{hits} } < $size ) {
		    $finished = 1;
		    $lastUsedScrollId = undef;
		}
		
		foreach my $entry ( @{ $response->{hits}->{hits} } ) {
		    #print STDERR "### Id is ", $entry->{_source}->{id}, ", _id is ", $entry->{_id}, "\n";
		    $handlerToCall->( $entry->{_source}, $entry->{_index}, $entry->{_type}, $entry->{_id}, $entry->{_score}, $entry->{_parent} );
		}
	    }
	    else {
		warn "No hits found\n";
		$finished = 1;
	    }
	}
	else {
	    warn "Sending http request failed\n";
	    $finished = 1;
	}

	unless( $finished ) {
	    my $url = $self->{elasticsearchUrl} . "/_search/scroll";
	    #print STDERR "Will send raw post request: $url\n";
	    ( $wasOkay, $response ) = $self->_sendRawHttpPostRequest( $url, $followUpBody );
	}

    } while( ! $finished );


    if ( defined( $lastUsedScrollId ) ) {
	# help elasticsearch to release resources
	$self->_clearScrollApi( $lastUsedScrollId );
    }

    # curl -XDELETE localhost:9200/_search/scroll -d '{ "scroll_id" : ["c2Nhbjs2OzM0NDg1ODpzRlBLc0FXNlNyNm5JWUc1"] }'

}
#############################################################################################
sub _clearScrollApi {
    my ( $self, $scrollId ) = @_;
    my $url = $self->{elasticsearchUrl} . "/_search/scroll?scroll_id=${scrollId}";
    $self->_sendRawHttpDeleteRequest( $url );
}
#############################################################################
sub checkIfIdExistsDEPRECATED {
    my( $self, $type, $idToFind ) = @_;

    my $element = $self->getElementWithId( $type, $idToFind );
    return( defined( $element ) );
}
#############################################################################
sub checkIfIdExists {
    my( $self, $type, $idToFind ) = @_;
    my $doesExist = 0;
    $self->_ensureHttpRequestPossible;

    my $url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/${type}/${idToFind}";

    my $request = $self->_createRequest( 'HEAD', $url );

    my $response = $self->{_userAgent}->request( $request );
    if ( $response->is_success ) {
        $doesExist = 1;
    }
    return( $doesExist );
}

#############################################################################
sub extractNumberOfResultsFromResponse {
    my( $self, $response ) = @_;
    my $numberOfResults = -1;
    
    if ( $response and exists( $response->{hits} ) ) {
        my $total = $response->{hits}->{total};
        if ( ref( $total ) eq "HASH" ) {
            $numberOfResults = $total->{value};
        }
        else {
            $numberOfResults = $total;
        }
    }
    return( $numberOfResults );
}
#############################################################################
sub checkIfAtLeastOneDocumentExistsWithValueInField {
    my( $self, $type, $fieldName, $valueToFind ) = @_;
    my $doesExist = 0;

    my $urlPostfix = "${type}/_search";
    my $body = { "query" => { "match" => { $fieldName => $valueToFind } } };

    my( $isSuccess, $response ) = $self->sendHttpPostRequest( $urlPostfix, $body );
    if ( $isSuccess and $response->{hits}->{total} > 0 ) {
	$doesExist = 1;
    }
    return( $doesExist );
}
#############################################################################
sub _createRequest {
    my( $self, $requestType, $url, $optionalContentType ) = @_;
    my $request = HTTP::Request->new( $requestType, $url );

    my $contentType = $optionalContentType ? $optionalContentType : 'application/json';

    # Setting the content-type is not requested by elasticsearch, but we do it anyway
    # In Version 6 of elasticsearch it is obviously required
    $request->header( 'Content-Type' => $contentType );

    if ( defined( $self->{accessToken} ) ) {
	my $value = 'Basic ' . $self->{accessToken};
	$request->header( 'Authorization' => $value  );
    }
    
    return( $request );
}
#############################################################################
sub checkForExistenceWithConditions {
    my( $self, $conditionHashRef ) = @_;

    my $searchParameters = { "size" => 0, "query" => { "bool" => { "must" => "" } } };
    my @mustMatches = ();
    while ( my ( $key, $value ) = each %$conditionHashRef ) {
	push( @mustMatches, { "match" => { $key => $value } } );
    }
    $searchParameters->{"query"}->{"bool"}->{"must"} = \@mustMatches;

    my( $wasSuccess, $responseStructure ) = $self->sendHttpPostRequest( "_search", $searchParameters );
    return( $wasSuccess and defined( $responseStructure ) and defined( $responseStructure->{"hits"} ) and $responseStructure->{"hits"}->{"total"} == 1 );
    
}
#############################################################################
sub getElementWithId {
    my( $self, $type, $idToFind ) = @_;
    my $foundElement = undef;
    
    $self->_ensureHttpRequestPossible;

    my $url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/${type}/${idToFind}";

    my $request = $self->_createRequest( 'GET', $url );

    my $response = $self->{_userAgent}->request( $request );
    if ( $response->is_success ) {
	
	# Note: response->content() will return a raw string (bytes)
	my $responseString = $response->content();
	# Note: json decoder expects a raw string (bytes) as input, not a string in perl's internal representation
	my $responseStructure = $self->{_jsonDecoder}->decode ( $responseString );
	
	if ( $responseStructure->{found} ) {
	    $foundElement = $responseStructure->{_source};
	}
    }
    else {
	# No error, if we don't find the document
    }

    #print STDERR "XXX found '$url'\n" if $foundElement;
    #print STDERR "XXX could not find '$url'\n" unless $foundElement;
    
    return( $foundElement );
}
#############################################################################
# Note: $parentId is optional
sub updatePerlStructure {
    my( $self, $type, $perlStructure, $id, $parentId ) = @_;
    
    $self->_ensureHttpRequestPossible;
    die "Cannot update perl structure: no id given\n" unless( defined( $id ) );

    my $url;
    if ( defined( $parentId ) ) {
	$url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/${type}/${id}/_update?parent=$parentId";
    }
    else {
	$url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/${type}/${id}/_update";
    }

    my $toAdd = $self->{_jsonCoder}->encode( { "doc" => $perlStructure } );
    
    my $request = $self->_createRequest( 'POST', "${url}" );
    $request->content( $toAdd );

    # write json structure to index
    my $postResponse = $self->{_userAgent}->request( $request );
    if ( $postResponse->is_success ) {
	print STDERR "Updating elasticsearch document succeeded, posted one change\n" if $self->{beVerbose};
    }
    else {
	$self->_errorInRequest( $request, $postResponse );
    }

    return( $postResponse->is_success );
}
#############################################################################
sub addPerlStructureWithId {
    my( $self, $type, $perlStructure, $id ) = @_;
    die "Cannot add perl structure: no id given\n" unless( defined( $id ) );
    $self->_addPerlStructureWithOptionalIdAndOptionalParent( $type, $perlStructure, $id, undef );
}
#############################################################################
sub addPerlStructureWithIdAndParent {
    my( $self, $type, $perlStructure, $id, $parent ) = @_;

    die "Cannot add perl structure: no id given\n" unless( defined( $id ) );
    die "Cannot add perl structure: no parent id given\n" unless( defined( $parent ) );
    $self->_addPerlStructureWithOptionalIdAndOptionalParent( $type, $perlStructure, $id, $parent );
}
#############################################################################
sub addPerlStructureWithAutomaticId {
    my( $self, $type, $perlStructure ) = @_;
    $self->_addPerlStructureWithOptionalIdAndOptionalParent( $type, $perlStructure, undef, undef );
}

#############################################################################
# Depending on the fact, if $idKey is defined or not, the structures will be inserted
# using explicite ids or automatically created ones
sub _addSeveralPerlStructuresViaBulk {
    my( $self, $idKey, $perlStructures ) = @_;
    $self->_ensureHttpRequestPossible;

    my $url;
    if ( HK::BaseUtils::compareNumericalVersions( $self->{elasticsearchVersion}, '7' ) >= 0 ) {
        # hk: the following line works from ES7 on! This line does not work for ES6!!
        $url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/_bulk";
    }
    else {
        # hk: in ES6 type _doc must be specified for a bulk request!!
        $url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/_doc/_bulk";
    }
    
    # hk: the header used to be "application/x-ndjson" in the past, but json seems to work, too;
    my $request = $self->_createRequest( 'POST', "${url}", "application/json" );

    my $toAdd = "";

    # Note: "create" will fail, if a document with this id already exists, "index" will succeed
    foreach my $oneStructure ( @$perlStructures ) {
	if ( defined( $idKey ) ) {
	    # Find the id key to use in $oneStructure->{$idKey}
	    $toAdd .= '{ "index" : { "_index": "' . $self->getCurrentIndex() . '", "_id": "' . $oneStructure->{$idKey} . '" } }';
	}
	else {
	    # Do not specify id, use automatically created ids of elasticsearch
	    $toAdd .= '{ "index" : { "_index": "' . $self->getCurrentIndex() . '" } }';
	}
	$toAdd .= "\n";
	$toAdd .= $self->{_jsonCoder}->encode( $oneStructure );
	$toAdd .= "\n";
    }
    #print STDERR "Will send POST request to URL ${url}. Post data is '$toAdd'\n" if $self->{beVerbose};
    
    $request->content( $toAdd );
    
    # send bulk request to index
    my $postResponse = $self->{_userAgent}->request( $request );

    my $errorMessage = undef;
    if ( $postResponse->is_success ) {
        $errorMessage = $self->_extractResponseErrorMessageIfAny( $postResponse );
        if ( ! defined( $errorMessage ) ) {
            print STDERR "Writing to elasticsearch succeeded, posted one block\n" if $self->{beVerbose};
        }
    }
    else {
        $errorMessage = "Error in elasticsearch bulk request. Error message was: " . $postResponse->status_line . "\n";
    }

    if ( defined( $errorMessage ) ) {
        my $postResponseObject = $self->{_jsonCoder}->decode( $postResponse->content() );
        if ( $postResponseObject->{"items"} ) {
            foreach my $x ( @{ $postResponseObject->{"items"} } ) {
                print STDERR "** The following element could not be inserted:\n", Dumper($x) if $x->{"index"}->{"error"};
            }
        }
	if ( $self->_isDieOnError() ) {
            #print STDERR Dumper($postResponse) if $self->{beVerbose};
	    confess( $errorMessage );
	}
	else {
	    carp( $errorMessage );
	}
    }
}
#############################################################################
sub _extractResponseErrorMessageIfAny {
    my( $self, $response ) = @_;
    my $answer = undef;
    
    my $responseString = $response->content();
    # Note: json decoder expects a raw string (bytes) as input, not a string in perl's internal representation
    my $responseStructure = $self->{_jsonDecoder}->decode ( $responseString );
    if ( $responseStructure->{errors} ) {
        foreach my $x ( @{$responseStructure->{items}} ) {
            if ( $x->{index}->{error} ) {
                $answer = $x->{index}->{error}->{reason} . "\n";
                last;
            }
        }
    }
    return( $answer );
}

#############################################################################
# Note: $idKey must be specified
sub updateSeveralPerlStructuresViaBulk {
    my( $self, $idKey, $perlStructures ) = @_;
    $self->_ensureHttpRequestPossible;

    unless( defined( $idKey ) ) {
        if ( $self->_isDieOnError() ) {
            confess( "Error in updateSeveralPerlStructuresViaBulk: no idKey specified.\n" );
        }
        else {
            carp( "Error in updateSeveralPerlStructuresViaBulk: no idKey specified.\n" );
        }
    }

    my $url;
    if ( HK::BaseUtils::compareNumericalVersions( $self->{elasticsearchVersion}, '7' ) >= 0 ) {
        # hk: the following line works from ES7 on! This line does not work for ES6!!
        $url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/_bulk";
    }
    else {
        # hk: in ES6 type _doc must be specified for a bulk request!!
        $url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/_doc/_bulk";
    }
    
    # hk: the header used to be "application/x-ndjson" in the past, but json seems to work, too;
    my $request = $self->_createRequest( 'POST', "${url}", "application/json" );

    my $toAdd = "";

    # Note: "create" will fail, if a document with this id already exists, "index" will succeed
    foreach my $oneStructure ( @$perlStructures ) {
        # Find the id key to use in $oneStructure->{$idKey}
        $toAdd .= '{ "update" : { "_index": "' . $self->getCurrentIndex() . '", "_id": "' . $oneStructure->{$idKey} . '" } }';
	$toAdd .= "\n";
	$toAdd .= $self->{_jsonCoder}->encode( { "doc" => $oneStructure } );
	$toAdd .= "\n";
    }
    #print STDERR "Will send POST request to URL ${url}. Post data is '$toAdd'\n" if $self->{beVerbose};
    
    $request->content( $toAdd );
    
    # send bulk request to index
    my $postResponse = $self->{_userAgent}->request( $request );
    if ( $postResponse->is_success ) {
	print STDERR "Writing to elasticsearch succeeded, posted one block\n" if $self->{beVerbose};
    }
    else {
	if ( $self->_isDieOnError() ) {
	    confess( "Error in elasticsearch bulk request. Error message was: " . $postResponse->status_line . "\n" );
	}
	else {
	    carp( "Error in elasticsearch bulk request. Error message was: " . $postResponse->status_line . "\n" );
	}
    }
}

#############################################################################
# $perlStructures is expected to be am array reference containing several
# perl structures to be inserted into the index
sub addSeveralPerlStructuresWithAutomaticIdsViaBulk {
    my( $self, $perlStructures ) = @_;
    $self->_addSeveralPerlStructuresViaBulk( undef, $perlStructures );
}

#############################################################################
# $perlStructures is expected to be am array reference containing several
# perl structures to be inserted into the index. Each perl structure must
# have a field with key $idKey to be used as insertion id
sub addSeveralPerlStructuresWithExpliciteIdsViaBulk {
    my( $self, $idKey, $perlStructures ) = @_;
    $self->_addSeveralPerlStructuresViaBulk( $idKey, $perlStructures );
}
#############################################################################
sub addPerlStructureWithAutomaticIdAndParent {
    my( $self, $type, $perlStructure, $parent ) = @_;
    die "Cannot add perl structure: no parent id given\n" unless( defined( $parent ) );
    $self->_addPerlStructureWithOptionalIdAndOptionalParent( $type, $perlStructure, undef, $parent );
}
    
#############################################################################
sub _addPerlStructureWithOptionalIdAndOptionalParent {
    my( $self, $type, $perlStructure, $id, $optionalParent ) = @_;
    
    $self->_ensureHttpRequestPossible;
    
    my $url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/${type}/";
    $url .= $id if defined( $id );
    $url .= "?parent=$optionalParent" if defined( $optionalParent );

    my $toAdd = $self->{_jsonCoder}->encode( $perlStructure );
    
    print STDERR "Will send POST request to URL ${url}. Post data is '$toAdd'\n" if $self->{beVerbose};
    my $request = $self->_createRequest( 'POST', "${url}" );
    
    $request->content( $toAdd );

    # write json structure to index
    my $postResponse = $self->{_userAgent}->request( $request );
    if ( $postResponse->is_success ) {
	print STDERR "Writing to elasticsearch succeeded, posted one element\n" if $self->{beVerbose};
    }
    else {
	$self->_errorInRequest( $request, $postResponse );
    }

    return( $postResponse->is_success );
}
#############################################################################
sub addPerlStructure {
    my( $self, $type, $perlStructure, $keyOfIdField ) = @_;

    my $id = $perlStructure->{$keyOfIdField} if defined( $keyOfIdField );
    return( $self->addPerlStructureWithId( $type, $perlStructure, $id ) );
}
#############################################################################
# The json structure is expected to contain a valid string with newlines for
# an elasticsearch bulk upload
sub addDocumentsViaBulkUpload {
    my( $self, $type, $jsonString ) = @_;
    my $url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/${type}/_bulk";

    my $request = $self->_createRequest( 'POST', "${url}" );
    $request->content( $jsonString );

    # write json structure to index
    my $postResponse = $self->{_userAgent}->request( $request );
    if ( $postResponse->is_success ) {
	print STDERR "Writing to elasticsearch succeeded, posted one bulk block\n" if $self->{beVerbose};
    }
    else {
	$self->_errorInRequest( $request, $postResponse );
    }

    return( $postResponse->is_success );
}

#############################################################################################
# 
sub _sendRawHttpDeleteRequest {
    my ( $self, $url ) = @_;
    my $responseStructure = undef;

    $self->_ensureHttpRequestPossible;

    my $request = $self->_createRequest( 'DELETE', "${url}" );
    my $response = $self->{_userAgent}->request( $request );
    if ( $response->is_success ) {
	
	# Note: response->content() will return a raw string (bytes)
	my $responseString = $response->content();
	# Note: json decoder expects a raw string (bytes) as input, not a string in perl's internal representation
	$responseStructure = $self->{_jsonDecoder}->decode ( $responseString );
	
	#die Dumper( $responseStructure );
    }
    else {
	$self->_errorInRequest( $request, $response );
    }
    return( $response->is_success, $responseStructure );
}
#############################################################################################
sub _errorInRequest {
    my ( $self, $request, $response ) = @_;
    if ( $self->_isDieOnError() ) {
	confess( "Error in elasticsearch request. Request was " . $request->as_string() . "\n" . $response->status_line . "\n" );
    }
    else {
	carp( "Error in elasticsearch request. Request was " . $request->as_string() . "\n" . $response->status_line . "\n" );
    }
}
#############################################################################################
# Please note that the given urlPostfix is expected to be encoded url safe
#
# Examples for $urlPostfix:
#   "_search/?q=id:\"${safeId}\"&size=0&terminate_after=1&pretty"
sub sendHttpGetRequest {
    my ( $self, $urlPostfix ) = @_;

    $self->_ensureHttpRequestPossible;

    my $url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/" . $urlPostfix;
    return( $self->_sendRawHttpGetRequest( $url ) );

}

#############################################################################################
# Please note that the given urlPostfix is expected to be encoded url safe
#
# Examples for $urlPostfix:
#   "_search/?q=id:\"${safeId}\"&size=0&terminate_after=1&pretty"
sub _sendRawHttpGetRequest {
    my ( $self, $url ) = @_;
    my $responseStructure = undef;

    $self->_ensureHttpRequestPossible;
    print STDERR "Will send HTTP get request. Used URL is: '$url'\n" if $self->{beVerbose};
    #die "Url for HTTP get request is: '$url'\n";

    my $request = $self->_createRequest( 'GET', "${url}" );
    my $response = $self->{_userAgent}->request( $request );
    if ( $response->is_success ) {
	
	# Note: response->content() will return a raw string (bytes)
	my $responseString = $response->content();
	# Note: json decoder expects a raw string (bytes) as input, not a string in perl's internal representation
	$responseStructure = $self->{_jsonDecoder}->decode ( $responseString );
	#die Dumper( $responseStructure );
    }
    else {
	$self->_errorInRequest( $request, $response );
    }
    return( $response->is_success, $responseStructure );
}

#############################################################################################
# Please note that the given urlPostfix is expected to be encoded url safe
#
# Examples for $urlPostfix:
#   "_search/?q=id:\"${safeId}\"&size=0&terminate_after=1&pretty"
sub sendHttpPostRequest {
    my ( $self, $urlPostfix, $bodyContent ) = @_;
    
    $self->_ensureHttpRequestPossible;

    my $url = $self->{elasticsearchUrl} . "/" . $self->{indexName} . "/" . $urlPostfix;
    print STDERR "Will send post request to URL '$url'. Body is\n", Dumper( $bodyContent ) if $self->{beVerbose};
    return( $self->_sendRawHttpPostRequest( $url, $bodyContent ) );
}
#############################################################################################
    
sub _sendRawHttpPostRequest {
    my ( $self, $url, $bodyContent ) = @_;
    my $responseStructure;
    my $responseString;

    my $toAdd = $self->{_jsonCoder}->encode( $bodyContent ) if defined( $bodyContent );
    #print "URL: $url\n";
    #print "NAME: ", $bodyContent->{query}->{match}->{name}, "\n";
    
    my $request = HTTP::Request->new( 'POST', "${url}" );
    
    if ( defined( $self->{accessToken} ) ) {
	my $value = 'Basic ' . $self->{accessToken};
	$request->header( 'Authorization' => $value  );
    }
    
    $request->header( 'Accept' => 'application/json; charset=UTF-8' );
    $request->header( 'Content-Type' => 'application/json; charset=UTF-8' );
    
    $request->content( $toAdd ) if defined( $toAdd );

    print STDERR "Will send request to ${url} with data $toAdd\n" if $self->{beVerbose};

    # write small json structure to dump index
    my $response = $self->{_userAgent}->request( $request );
    if ( $response->is_success ) {

	# Note: response->content() will return a raw string (bytes)
	$responseString = $response->content();
	# Note: json decoder expects a raw string (bytes) as input, not a string in perl's internal representation
	$responseStructure = $self->{_jsonDecoder}->decode ( $responseString );
	
	#die Dumper( $responseStructure );
    }
    else {
	$self->_errorInRequest( $request, $response );
    }
    return( $response->is_success, $responseStructure, $responseString );
}

#############################################################################################
sub _isDieOnError {
    my ( $self ) = @_;
    return( $self->{dieOnError} );
}
#############################################################################################
sub _ensureHttpRequestPossible {
    my ( $self ) = @_;
    my $isInitializedProperly = 1;

    unless( defined( $self->{indexName} ) ) {
	$isInitializedProperly = 0;
    }

    if ( !$isInitializedProperly ) {
	die "Elasticsearch manager is not configured properly: no index chosen\n";
    }
}

1;
