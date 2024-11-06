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
    $elasticsearchStructure->{name} = $elementToAdd->{properties}->{WAHLBEZI};
    $elasticsearchStructure->{municipality_id} = $elasticsearchStructure->{name};  # municipalityId == name
    $elasticsearchStructure->{id} = $elasticsearchStructure->{municipality_id} . "_" . sprintf( "%04d", $$counterReference );  # name was not unique!!
    $$counterReference++;
#    if ( $elasticsearchStructure->{name} ne "1010" and $elasticsearchStructure->{name} ne "0745" and $elasticsearchStructure->{name} ne "0610" and
#	 $elasticsearchStructure->{name} ne "1810" and $elasticsearchStructure->{name} ne "0820" and $elasticsearchStructure->{name} ne "0470" ) {
    if ( 1 ) {  # currently no region contains illegal data after repairing via prepair
	$elasticsearchStructure->{shapeType} = $geometryElement->{type};
	$elasticsearchStructure->{coordinates} = $coordinates;
	$elasticsearchStructure->{geolocation} = { "type" => $geometryElement->{type}, "coordinates" => $coordinates };

	$elasticsearchManager->addPerlStructure( $type, $elasticsearchStructure, "id" );
    }
    else {
	print STDERR "Skipped Wahlbezirk ", $elasticsearchStructure->{name}, " with id ", $elasticsearchStructure->{id}, "\n";
    }

    #print Dumper( $elementToAdd );
}
#############################################################################

sub getArrayOfCoordinates {
    my $resultArray = [];

    if ( @_ == 2 and  looks_like_number( $_[0] ) ) {
	push( @$resultArray, $_[1] );
	push( @$resultArray, $_[0] );
    }
    else {
	foreach my $element ( @_ ) {
	    push( @$resultArray, getArrayOfCoordinates( @$element ) );
	}
    }

    return( $resultArray );
}
#############################################################################

sub printCoordinates {
    my( $isFirst ) = shift( @_ );
    print "," unless $isFirst;

    print "[ ";
    if ( @_ == 2 and  looks_like_number( $_[0] ) ) {
	print $_[1] . "," . $_[0];
    }
    else {
	my $i = 0;
	foreach my $element ( @_ ) {
	    printCoordinates( $i == 0, @$element );
	    $i++;
	}
    }
    print " ]\n";
}




