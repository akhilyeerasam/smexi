#!/bin/bash

function getRootDirectoryOfThisScript {
    # resolve links - $0 may be a softlink
    PRG=`readlink -f $0`
    PRGDIR=`dirname "$PRG"`
    echo `realpath "${PRGDIR}/.."`
    #echo "$PRGDIR"
}

if test $# -ne 1; then
    echo "Usage: $0 <elasticsearchUrl>  (* Example: $0 http://localhost:9200 *)"
    exit -1
fi;

elasticsearchUrl=$1
rootDirectory=`getRootDirectoryOfThisScript`

echo "Do you really want to recreate all indices for ganesha shape data on ${elasticsearchUrl}? All existing entries will be lost!!!  (y/n)";
read userInput
if test x"$userInput" != x"y" && test x"$userInput" != x"Y" ; then
    echo "Cancelled by user"
    exit 1;
fi

mappingFile="${rootDirectory}/etc/elasticsearch_shapes_generic_mappings.json"

baseIndexName=shape_data

for i in kaiserslautern_suburbs kaiserslautern_electorate_regions kaiserslautern_primary_school_regions kaiserslautern_statistical_regions kaiserslautern_muncipality_regions; do
    ${rootDirectory}/bin/recreateIndexGeneric.sh -m "$mappingFile" -i "shape_data_$i" http://localhost:9200
    echo ""
done
