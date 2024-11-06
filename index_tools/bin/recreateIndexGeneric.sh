#!/bin/bash

function getDirectoryOfThisScript {
    # resolve links - $0 may be a softlink
    PRG=`readlink -f $0`
    PRGDIR=`dirname "$PRG"`
    echo `realpath "${PRGDIR}"`
    #echo "$PRGDIR"
}

function usage {
    cat << END_OF_USAGE
Syntax: $0 [options] <elasticsearchBaseUrl>

Delete the given index if it exists, the recreate an empty index using the given mapping.

Options:
    -h                    This help.
    -m <mappingFile>      The mapping file to be used for recreation
    -i <indexName>        The name of the index to be recreated
    -a <accessToken>>     Optional: an access token to use for the elasticsearch index

Please note that options -m and -i are mandatory.

Example:
    $0 -m ~/bin/AloeEcosystemTools/modules/aloe/etc/elasticsearch_aloe_mapping.json -i mindpool_dev http://localhost:9200


END_OF_USAGE

}

. "$(getDirectoryOfThisScript)/../lib/include_recreateElasticsearchInstanceGeneric.sh"

mappingFile=
indexName=
accessTokenString=
# Parse commandline options.
while getopts m:i:a:h option; do
    case ${option} in
        m)
            mappingFile="${OPTARG}"
            ;;
        i)
            indexName="${OPTARG}"
            ;;
        a)
            accessTokenString="${OPTARG}"
            ;;
        h|?)
            usage
            exit -1
        ;;
    esac
done

# remove all processed arguments
shift $((${OPTIND}-1))

if [ $# -ne 1 ]; then
    usage
    exit -1
fi
elasticsearchBaseUrl=$1

if [ ! -z $mappingFile ] && [ ! -z $indexName ]; then
    if [ ! -z $accessTokenString ]; then
        reinitializeIndex -a $accessTokenString "$elasticsearchBaseUrl" "$mappingFile" "$indexName"
    else
        reinitializeIndex "$elasticsearchBaseUrl" "$mappingFile" "$indexName"
    fi
    exit $?
else
    usage
    exit -1
fi

