#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
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
Please specify an additional metadata csv-file via option --metadataFile

Sample call:
  $0 --inputDataType json --dataIsInField features --elasticsearchUrl 'http://localhost:9200' --blockSize 1000 --metadataFile statistischeBezirke.csv statistischeBezirke.geojson
EOTEXT
    return( $errorString );
}
#############################################################################
sub main {
    my $metadataFile;
    
    my $genericImporter = HK::GenericImporter->new();
    my $elasticsearchManager = HK::ElasticsearchManager->new();

    HK::BaseUtils::checkCommandlineAndInitSeveralParameterManagers( \@ARGV, 1, getUsageString(), $elasticsearchManager, $genericImporter );
    checkCommandline( \@ARGV, \$metadataFile );

    my $metadata = getMetadataArray( $metadataFile );
    unless( $elasticsearchManager->isIndexChosen() ) {
	die "Please choose an index via commandline parameter\n";
    }
    
    my $counter = 1;
    $genericImporter->addHandler( sub { handleOneProject( \$counter, $metadata, $elasticsearchManager, @_ ); } );
    $genericImporter->startProcessing();
}
#############################################################################
sub getMetadataArray {
    my ( $metadataFile ) = @_;

    my @csvImportArguments = ( "--inputDataType", "csv", "--inputDataEncoding", "utf-8", "--blockSize", 1000, $metadataFile );
    my $genericImporter = HK::GenericImporter->new();
    my( $managerCheckWasSuccessful, $errorString ) = HK::BaseUtils::checkCommandlineAndInitSeveralParameterManagers( \@csvImportArguments, 0, undef, $genericImporter );

    my %metadataArray = ();
    $genericImporter->addHandler( sub { $metadataArray{$_[0]->{"Statistische Bezirke Nr"}} = $_[0]; } );
    $genericImporter->startProcessing();

    #die Dumper( %metadataArray );
    return( \%metadataArray );
}

#############################################################################

# Note: hook should return number of elements processed (used to avoid system overload)?
sub handleOneProject {
    my( $counterReference, $metadata, $elasticsearchManager, $elementToAdd, $importParameterManager ) = @_;
    my $type = "_doc";

    # do something with the retrieved data, which is a simple hash
    my $geometryElement = $elementToAdd->{geometry};
    my $coordinates = $geometryElement->{coordinates};


    my $elasticsearchStructure = {};
    my $statisticalId = $elementToAdd->{properties}->{STAT_BEZ};
    $elasticsearchStructure->{name} = $statisticalId;
    $elasticsearchStructure->{municipality_id} = $elasticsearchStructure->{name};  # municipalityId == name

    $statisticalId =~ s/^0*//;  # remove trailing zeroes
    if ( exists( $metadata->{$statisticalId} ) ) {
	# Available metadata in corresponding CSV file:
	#     'Statistische Bezirke Nr' => '1720',
	#     'Statistische Bezirke BEZ' => '1720 Siegelbach Nord',
	#     'Ortsbezirke BEZ' => 'Siegelbach',
	#     'Ortsbezirke Nr' => '17'
	my $metadataForOneElement = $metadata->{$statisticalId};
	my $regionName = $metadataForOneElement->{"Statistische Bezirke BEZ"};
	$regionName =~ s/^\d*\s+//;
	my $descriptionString = $regionName . " (Ortsbezirk " . $metadataForOneElement->{"Ortsbezirke Nr"} . " " . $metadataForOneElement->{"Ortsbezirke BEZ"} . ")";
	$elasticsearchStructure->{description} = $descriptionString;
    }
    else {
	#$elasticsearchStructure->{description} = "Unknown statistical region $statisticalId";
	die "No metadata found for $statisticalId\n";
    }
    
    $elasticsearchStructure->{id} = $elasticsearchStructure->{municipality_id};  # better use the (unique) municipalityId here, too
    $$counterReference++;
    if ( 1 ) {  # currently no region contains illegal data after repairing via prepair
	$elasticsearchStructure->{shapeType} = $geometryElement->{type};
	$elasticsearchStructure->{coordinates} = $coordinates;
	$elasticsearchStructure->{geolocation} = { "type" => $geometryElement->{type}, "coordinates" => $coordinates };

	$elasticsearchManager->addPerlStructure( $type, $elasticsearchStructure, "id" );
    }
    else {
	print STDERR "Skipped statistical region ", $elasticsearchStructure->{name}, " with id ", $elasticsearchStructure->{id}, "\n";
    }

    #print Dumper( $elementToAdd );
}

#############################################################################
sub checkCommandline {
    my ( $optionsArrayRef, $metadataFile ) = @_;
    my $helpMe;

    # Check command line
    if ( GetOptionsFromArray( $optionsArrayRef,
                              "metadataFile=s" => $metadataFile,
                              "h" => \$helpMe, "help" => \$helpMe ) ) {
        # okay
        if ( $helpMe ) {
            # nothing else needed: don't check command line
        }
        else {
            if ( ! defined( $$metadataFile ) ) {
                warn "** Option --metadataFile is missing\n";
                $helpMe = 1;
            }
        }
    }
    else {
        $helpMe = 1;
    }

    #print Dumper( $self );

    if ( $helpMe ) {
        my $myHelpText = getUsageString();
        die $myHelpText;
    }
}


