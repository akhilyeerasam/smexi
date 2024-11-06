#!/bin/bash

function getRootDirectoryOfThisScript {
    # resolve links - $0 may be a softlink
    PRG=`readlink -f $0`
    PRGDIR=`dirname "$PRG"`
    echo `realpath "${PRGDIR}/.."`
    #echo "$PRGDIR"
}

if test $# -ne 1; then
    echo "Usage: $0 <elasticsearchUrl> <shapeFileDirectory>   (* Example: $0 http://localhost:9200 *)"
    exit -1
fi;
elasticsearchUrl=$1
rootDirectory=`getRootDirectoryOfThisScript`

dataDirectory="${rootDirectory}/data"
#dataDirectory="/home/kirchman/Projects/ganesha/osnabrueckShapes/shapeFiles"

for i in $elasticsearchUrl; do
    yes | ${rootDirectory}/bin/hkMiniRecreateKaiserslauternShapeDataElasticsearch.sh $i
    ${rootDirectory}/bin/shapesToElasticsearch_kaiserslautern_suburbs.pl --inputDataType json --dataIsInField features --blockSize 1000 --elasticsearchHttpTimeout 900 --elasticsearchUrl http://localhost:9200 --indexName shape_data_kaiserslautern_suburbs ${dataDirectory}/ortsbezirke_withMunicipalityIdAndUtf8.geojson
    ${rootDirectory}/bin/shapesToElasticsearch_kaiserslautern_primarySchoolRegions.pl --inputDataType json --dataIsInField features --blockSize 1000 --elasticsearchHttpTimeout 900 --elasticsearchUrl http://localhost:9200 --indexName shape_data_kaiserslautern_primary_school_regions ${dataDirectory}/schulbezirkeGrundschulen.geojson
    ${rootDirectory}/bin/shapesToElasticsearch_kaiserslautern_electorateRegions.pl --inputDataType json --dataIsInField features --blockSize 1000 --elasticsearchHttpTimeout 900 --elasticsearchUrl http://localhost:9200 --indexName shape_data_kaiserslautern_electorate_regions ${dataDirectory}/wahlbezirke.geojson
    ${rootDirectory}/bin/shapesToElasticsearch_kaiserslautern_statisticalRegions.pl --inputDataType json --dataIsInField features --blockSize 1000 --elasticsearchHttpTimeout 900 --elasticsearchUrl http://localhost:9200 --indexName shape_data_kaiserslautern_statistical_regions --metadataFile ${dataDirectory}/statistischeBezirke.csv ${dataDirectory}/statistischeBezirke.geojson
    ${rootDirectory}/bin/shapesToElasticsearch_kaiserslautern_MunicipalityId_withStatIdMappings.pl --inputDataType json --dataIsInField features --blockSize 1000 --elasticsearchHttpTimeout 900 --elasticsearchUrl http://localhost:9200 --indexName shape_data_kaiserslautern_muncipality_regions --metadataFile ${dataDirectory}/statistischeBezirke.csv ${dataDirectory}/ortsbezirke_withMunicipalityId_withStatIdMappings.geojson

done

echo "Did insert all shape data into corresponding index instances at $elasticsearchUrl"
