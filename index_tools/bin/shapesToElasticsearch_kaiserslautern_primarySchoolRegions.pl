#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

use FindBin qw($RealBin);
use lib ( "$RealBin/../lib", "$RealBin/../libAloeEcosystem" );

use HK::ElasticsearchManager;
use HK::ImportParameterManager;
use HK::GenericImporter;
use HK::BaseUtils;
use open qw(:std :utf8);

main();

#############################################################################
sub getUsageString {
    my $errorString = <<"EOTEXT";
Sample call csv:
  $0 --importVerbosity 100 --inputDataType csv --maxNumberOfInserts 10 /any/where/publications_2015_09_03.csv
Sample call json:
  $0 --importVerbosity 100 --inputDataType json --maxNumberOfInserts 10 /any/where/G09B-201309-501-600.epo.json.gz.uniform.json
EOTEXT
    return( $errorString );
}
#############################################################################
sub main {
    my $genericImporter = HK::GenericImporter->new();
    my $elasticsearchManager = HK::ElasticsearchManager->new();
    HK::BaseUtils::checkCommandlineAndInitSeveralParameterManagers( \@ARGV, 1, getUsageString(), $elasticsearchManager, $genericImporter );
    unless( $elasticsearchManager->isIndexChosen() ) {
	die "Please choose an index via commandline parameter\n";
    }
    
    my $counter = 1;
    $genericImporter->addHandler( sub { handleOneProject( \$counter, $elasticsearchManager, @_ ); } );
    $genericImporter->startProcessing();
}
#############################################################################

# Note: hook should return number of elements processed (used to avoid system overload)?
sub handleOneProject {
    my( $counterReference, $elasticsearchManager, $elementToAdd, $importParameterManager ) = @_;
    my $type = "_doc";

    # do something with the retrieved data, which is a simple hash
    my $geometryElement = $elementToAdd->{geometry};
    my $coordinates = $geometryElement->{coordinates};

    my $elasticsearchStructure = {};
    $elasticsearchStructure->{name} = $elementToAdd->{properties}->{Schule};
    $elasticsearchStructure->{municipality_id} = $elasticsearchStructure->{name};  # municipalityId == name

    my $idToUse = sprintf( "%03d ", $$counterReference ) . $elasticsearchStructure->{municipality_id};
    $$counterReference++;
    $elasticsearchStructure->{id} = $idToUse;
    
    $elasticsearchStructure->{shapeType} = $geometryElement->{type};
    $elasticsearchStructure->{coordinates} = $coordinates;
    #print Dumper( $elasticsearchStructure );

    $elasticsearchStructure->{geolocation} = { "type" => $geometryElement->{type}, "coordinates" => $coordinates };

    $elasticsearchManager->addPerlStructure( $type, $elasticsearchStructure, "id" );
    #print Dumper( $elementToAdd );
}
