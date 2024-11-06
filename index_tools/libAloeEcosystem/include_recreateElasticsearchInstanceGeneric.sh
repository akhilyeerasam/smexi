#!/bin/bash

#########################################################################################################
function _getElasticsearchIndexMajorVersionNumber {
    # Note: expected is one parameter: the base URL of the elasticsearch service, like e.g. http://localhost:9200
    perl -e 'use JSON::XS;my $jsonCoder = JSON::XS->new->allow_nonref; my $elasticInfo = `curl -s -H "Content-Type: application/json; charset=UTF-8;" -XGET "$ARGV[0]"`; my $elasticInfoObject = $jsonCoder->decode( $elasticInfo ); print $elasticInfoObject->{version}->{number} =~ m/^(\d)+/, "\n";' "$1";
}

#########################################################################################################
function _mappingFileContainsType {
    # Note: expected is one parameter: the path to a mapping file
    #echo $(perl -e 'use JSON::XS;my $jsonCoder = JSON::XS->new->allow_nonref; my $mappingInfo = `cat "$ARGV[0]"`; my $mappingInfoObject = $jsonCoder->decode( $mappingInfo ); print $mappingInfoObject->{mappings}, "\n";' "$1")
    # Note: If the object found in the file given as parameter
    perl -e 'use JSON::XS;my $jsonCoder = JSON::XS->new->allow_nonref; my $mappingInfo = `cat "$ARGV[0]"`; my $mappingInfoObject = $jsonCoder->decode( $mappingInfo ); if ( exists( $mappingInfoObject->{mappings} ) && exists( $mappingInfoObject->{mappings}->{_doc} ) ) { print "y\n"; } else { print "n\n"; }' "$1";
}

#########################################################################################################
function _mappingFileHasToplevelMappingsElement {
    # Note: expected is one parameter: the path to a mapping file
    #echo $(perl -e 'use JSON::XS;my $jsonCoder = JSON::XS->new->allow_nonref; my $mappingInfo = `cat "$ARGV[0]"`; my $mappingInfoObject = $jsonCoder->decode( $mappingInfo ); print $mappingInfoObject->{mappings}, "\n";' "$1")
    # Note: If the object found in the file given as parameter
    perl -e 'use JSON::XS;my $jsonCoder = JSON::XS->new->allow_nonref; my $mappingInfo = `cat "$ARGV[0]"`; my $mappingInfoObject = $jsonCoder->decode( $mappingInfo ); if ( exists( $mappingInfoObject->{mappings} ) ) { print "y\n"; } else { print "n\n"; }' "$1";
}

#########################################################################################################
function _adjustMappingToElasticsearch7 {
    # Note: expected is one parameter: the path to a mapping file
    #       Return value: an absolute path to a newly created and adjusted mapping file or the input file in case no adjustment was needed
    perl -e 'use strict;use warnings;use JSON::XS;use File::Temp qw(tempfile);my $jsonCoder = JSON::XS->new->pretty->allow_nonref; my $mappingInfo = `cat "$ARGV[0]"`; my $mappingInfoObject = $jsonCoder->decode( $mappingInfo ); if ( exists( $mappingInfoObject->{mappings} ) and exists( $mappingInfoObject->{mappings}->{_doc} ) ) { my $x = $mappingInfoObject->{mappings}->{_doc}; delete( $mappingInfoObject->{mappings}->{_doc} ); $mappingInfoObject->{mappings} = $x; my ( $temporaryFileHandle, $temporaryFile ) = tempfile();print $temporaryFileHandle $jsonCoder->encode( $mappingInfoObject ), "\n"; close( $temporaryFileHandle ); print "$temporaryFile\n"; } else { print $ARGV[0], "\n"; };' "$1";
}

#########################################################################################################
function _adjustMappingToElasticsearch6 {
    # Note: expected is one parameter: the path to a mapping file
    #       Return value: an absolute path to a newly created and adjusted mapping file or the input file in case no adjustment was needed
    perl -e 'use strict;use warnings;use JSON::XS;use File::Temp qw(tempfile);my $jsonCoder = JSON::XS->new->pretty->allow_nonref; my $mappingInfo = `cat "$ARGV[0]"`; my $mappingInfoObject = $jsonCoder->decode( $mappingInfo ); if ( exists( $mappingInfoObject->{mappings} ) and not exists( $mappingInfoObject->{mappings}->{_doc} ) ) { my $x = $mappingInfoObject->{mappings}->{properties}; delete( $mappingInfoObject->{mappings}->{properties} ); $mappingInfoObject->{mappings} = {_doc => { "properties" => $x } }; my ( $temporaryFileHandle, $temporaryFile ) = tempfile();print $temporaryFileHandle $jsonCoder->encode( $mappingInfoObject ), "\n"; close( $temporaryFileHandle ); print "$temporaryFile\n"; } else { print $ARGV[0], "\n"; };' "$1";
}

#########################################################################################################
# Please note: The mapping is adjusted to the version of Elasticsearch service. Version < 7.0 are assumed to use
#              _doc as type parameter, in versions >= 7.0 the type parameters are eliminated!!
#
# Call this function like this:
#   reinitializeIndex <allCommandlineParameters> <mappingFile> <presetIndexName>
#   Example:
#      reinitializeIndex $@ "elasticsearch_kosis_movement_kaiserslautern_mappings.json" "kosis_kaiserslautern"
# We assume that the calling script will accept optional parameters
#   -a     to specify an access token to be used for elasticsearch authentication
#   -i     to specify an index to be used instead of preset index
# and takes one argument, the elasticsearch base address
#
#########################################################################################################
function reinitializeIndex {
    # By declaring an argument array, we can add further parameters later on.
    local -a curlBaseArgumentsArray=('--header' 'Content-Type: application/json; charset=UTF-8;' '--silent' '--show-error')
    local accessTokenOption instanceName presetIndexName option elasticsearchUrl userInput usageString mappingRelativeFilename temporaryFileToRemove
    # *** Note: usageString must be quoted when echoed to preserve the newlines
    usageString=$(cat <<'EOF'
Syntax: $0 [options] <elasticsearchUrl>

Delete the given index (if it already exists) and reconfigure the mapping

Options:
    -h                  This help.
    -i <name>           name of index to use (overwrite the setting in the calling script via commandline)
    -a <accessToken>    If elasticsearch index is configured to use authentication, use the following access key

Example:
    $0 http://localhost:9200
    $0 -i another_index -a abcZWxDEFhsagdafvasdfjdj2w= http://localhost:9200
EOF
	       )

    accessTokenOption=()
    indexName="$presetIndexName"

    # If processing parameters from inside a function do not forget to declare the OPTIND variable as local
    local OPTIND

    # Parse commandline options.
    while getopts hi:a: option; do
	case ${option} in
            a)
		accessToken="${OPTARG}"
                curlBaseArgumentsArray=("${curlBaseArgumentsArray[@]}" '--header' "Authorization: Basic ${accessToken}")
		;;
            i)
		indexName="${OPTARG}"
		;;
            h|?)
                echo "$usageString"
		exit 1
		;;
	esac
    done

    # remove all processed arguments
    shift $((${OPTIND}-1))


    if test $# -ne 3; then
	echo "$usageString"
	exit -1
    fi

    elasticsearchUrl=$1


    mappingFile=$2
    presetIndexName=$3

    # set $indexName to $presetIndexName if variable $indexName is not set (that is: was not specified on commandline by user)
    indexName=${indexName:-$presetIndexName}

    ########################################################
    # Adjust mapping according to the used elasticsearch version
    ########################################################
    elasticsearchMajorVersion=$(_getElasticsearchIndexMajorVersionNumber "$elasticsearchUrl")
    doesMappingContainType=$(_mappingFileContainsType "$mappingFile")
    if [ $doesMappingContainType == "y" ] && [ $elasticsearchMajorVersion -gt 6 ]; then
        newMappingFile=$(_adjustMappingToElasticsearch7 "$mappingFile")
        echo "** Note: Mapping contains 'type' but Elasticsearch major version is greater 6. Created a temporary version of an adjusted mapping file: $newMappingFile"
        echo ""
        if [ x"$newMappingFile" != x"$mappingFile" ]; then
            mappingFile="$newMappingFile"
            temporaryFileToRemove="$mappingFile"
        fi
    elif [ $doesMappingContainType == "n" ] && [ $elasticsearchMajorVersion -le 6 ]; then
        newMappingFile=$(_adjustMappingToElasticsearch6 "$mappingFile")
        echo "** Note: Mapping does not contain 'type' but Elasticsearch major version is <= 6. Created a temporary version of an adjusted mapping file: $newMappingFile"
        echo ""
        if [ x"$newMappingFile" != x"$mappingFile" ]; then
            mappingFile="$newMappingFile"
            temporaryFileToRemove="$mappingFile"
        fi
    fi

    # Variable hasMappingFileToplevelMappingElement will indicate if the structure in the mapping file is of form
    #   { "mappings": {}, ... }
    #          or
    #   { "properties": {}, ... }
    # In the latter case processing has to be slightly different (that is: we have to create the index first, then initialize the mapping)
    hasMappingFileToplevelMappingElement=$(_mappingFileHasToplevelMappingsElement "$mappingFile")

    if [ $hasMappingFileToplevelMappingElement == "y" ]; then
        # we initialize just using <baseUrl>/<indexName>
        urlToBeUsedForMappingInitialization="${elasticsearchUrl}/${indexName}"
    else
        # we initialize just using <baseUrl>/<indexName>/_mapping[/_doc] where _doc may only be used in elasticsearch versions < 7
        if [ $elasticsearchMajorVersion -le 6 ]; then
            urlToBeUsedForMappingInitialization="${elasticsearchUrl}/${indexName}/_mapping/_doc"
        else
            urlToBeUsedForMappingInitialization="${elasticsearchUrl}/${indexName}/_mapping"
        fi
    fi

    ########################################################
    # Just a block for debugging purpose. Enable if needed
    ########################################################
    if false; then
	echo "Elasticsearch URL: $elasticsearchUrl"
	echo "Preset index name: $presetIndexName"
	echo "Actual index name: $indexName"
	echo "Confirmation infix: $confirmationInfix"
	echo "Name of mapping file: $mappingFile"
    fi

    returnValue=0

    # echo "Do you really want to recreate index $indexName on ${elasticsearchUrl}? All existing entries will be lost!!!  (y/n)";
    # read userInput
    # if test x"$userInput" != x"y" && test x"$userInput" != x"Y" ; then
	# echo "Cancelled by user: did not recreate ${indexName} on ${elasticsearchUrl}!"
    # else
        # delete index, if it already exists
	curl "${curlBaseArgumentsArray[@]}" -I -f "${elasticsearchUrl}/${indexName}" >/dev/null 2>&1 && echo "Will delete index ${indexName}" && \
            curl "${curlBaseArgumentsArray[@]}" -XDELETE "${elasticsearchUrl}/${indexName}"
	echo ""

        ########################################################
        # If the mapping affects just the properties, we have
        # to create the index first, then add the mapping.
        # Otherwise creation and adding the mapping is one step.
        ########################################################
        if [ $hasMappingFileToplevelMappingElement == "y" ]; then
            echo "Will create index ${indexName} using mapping file ${mappingFile}"
        else
            # create index
	    echo "Will create index ${indexName} at ${elasticsearchUrl}"
	    curl "${curlBaseArgumentsArray[@]}" -XPUT "${elasticsearchUrl}/${indexName}"
	    echo ""
	    echo "Will adjust mapping of ${indexName} using ${mappingFile}"
        fi
        
        # Note: getting a meaningful return value only works with option -f but then we don't see the server error either :-(
	curl "${curlBaseArgumentsArray[@]}" -f -XPUT "${urlToBeUsedForMappingInitialization}" -d "@${mappingFile}"
        returnValue=$?
        
        if [ $returnValue -ne 0 ]; then
            echo "Return value $returnValue indicated an error."
            if [ $hasMappingFileToplevelMappingElement != "y" ]; then
                # index might already be created. Delete it
                # delete index, if it was already created. Tell user to execute creation without
	        curl "${curlBaseArgumentsArray[@]}" -I -f "${elasticsearchUrl}/${indexName}" &>/dev/null && \
                    curl "${curlBaseArgumentsArray[@]}" -XDELETE "${elasticsearchUrl}/${indexName}" &>/dev/null
            fi
            echo "Initializing the mapping failed. To get more info, try: " curl "${curlBaseArgumentsArray[@]}" -XPUT "${urlToBeUsedForMappingInitialization}" -d "@${mappingFile}"
        fi
	echo ""
    #fi

    if [ ! -z $temporaryFileToRemove ]; then
        if [ $returnValue -eq 0 ]; then
            echo "Will remove $temporaryFileToRemove"
            rm $temporaryFileToRemove
        fi
    fi;

    return $returnValue

}

