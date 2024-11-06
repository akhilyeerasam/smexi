#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case :config pass_through);
use Time::Piece;
use Storable qw(dclone);

use FindBin qw($RealBin);
use lib ( "$RealBin/../lib", "$RealBin/../libAloeEcosystem" );

use XML::XPath;
use XML::XPath::XMLParser;
use JSON::XS;

use HK::BaseUtils;
use HK::ElasticsearchManager;
use HK::ImportParameterManager;
use HK::GenericImporter;

use open qw(:std :utf8);

main();


#############################################################################
sub main {
    my $genericImporter = HK::GenericImporter->new();
    my $elasticsearchManager = HK::ElasticsearchManager->new();
    my $snapshotDay;

    my @copyOfArgv = ( @ARGV );

    checkCommandLine( \$snapshotDay, $genericImporter, $elasticsearchManager );

    
    my $nodeHash = {};   # hash reference
    my $wayHash = {};   # hash reference
    
    $genericImporter->addHandler( sub { handleJustPlainNodes( $nodeHash, @_ ); } );
    $genericImporter->startProcessing();

    my $howMany = keys(%$nodeHash);
    #print STDERR "Stored $howMany nodes\n";

    $genericImporter = HK::GenericImporter->new();
    # checkCommandLine unsets pass_through for parameter check, so here we have to reactivate it
    Getopt::Long::Configure( "pass_through" );
    # Read away the elasticsearch parameters, otherwise genericImporter will interpret them as file names (hk design error, GRRR)
    HK::ElasticsearchManager->new()->initFromCommandlineParameters( \@copyOfArgv );
    $genericImporter->initFromCommandlineParameters( \@copyOfArgv );
    
    my $storage = [];   # array reference
    
    $genericImporter->addHandler( sub { handleOneEntry( $nodeHash, $wayHash, $storage, $snapshotDay, $elasticsearchManager, @_ ); } );
    $genericImporter->startProcessing();
    
    if ( @$storage > 0 ) {
        $elasticsearchManager->addSeveralPerlStructuresWithExpliciteIdsViaBulk( "id", $storage );
	print STDERR "Added final " . @$storage . " units of data\n";
    }

    exit( 0 );
}

#############################################################################
sub handleJustPlainNodes {
    my( $nodeStorage, $elementToAdd, $importParameterManager ) = @_;

    if ( exists($elementToAdd->{type}) and (lc($elementToAdd->{type}) eq "node") and defined($elementToAdd->{lat}) and defined($elementToAdd->{lon}) ) {
        $nodeStorage->{$elementToAdd->{id}} = {lat => $elementToAdd->{lat}+0, lon => $elementToAdd->{lon}+0 };
    }
    
}
#############################################################################
sub handleOneEntry {
    my( $nodeHash, $wayHash, $storage, $snapshotDay, $elasticsearchManager, $elementToAdd, $importParameterManager ) = @_;
    
    my $maxInserts = 1000;
    if ( @$storage > 0 && @$storage % $maxInserts == 0 ) {
        $elasticsearchManager->addSeveralPerlStructuresWithExpliciteIdsViaBulk( "id", $storage );
	print STDERR "Added " . @$storage . " units of data\n";
	@$storage = ();
    }

    my $elementType = $elementToAdd->{type};
    if ( exists( $elementToAdd->{tags} ) ) {
        my $tags = $elementToAdd->{tags};

        
        if ( $elementType eq "node" and exists( $tags->{name} ) and defined($elementToAdd->{lat}) and defined($elementToAdd->{lon}) ) {
            #print STDERR "Will add node ", $tags->{name}, "\n";
            my $toAdd = _createElasticsearchDocument( $nodeHash, $snapshotDay, $elementType, $elementToAdd, $elementToAdd->{lat}+0, $elementToAdd->{lon}+0 );
            push( @$storage, $toAdd );
        }
        if ( $elementType eq "way" ) {
            if ( exists( $elementToAdd->{nodes} ) ) {
                my @nodes = @{ $elementToAdd->{nodes} };
                if ( @nodes > 1 ) {
                    my $first = $nodes[0];
                    my $last = $nodes[-1];
                    if ( $first eq $last ) {
                        my $point = $nodeHash->{$first};
                        if ( defined( $point ) ) {
                            my $toAdd = _createElasticsearchDocument( $nodeHash, $snapshotDay, $elementType, $elementToAdd, $point->{lat}+0, $point->{lon}+0, _buildShape( "Polygon", $elementToAdd->{nodes}, $nodeHash ) );
                            #my $toAdd = _createElasticsearchDocument( $nodeHash, $snapshotDay, $elementType, $elementToAdd, $point->{lat}+0, $point->{lon}+0, _buildShape( "LineString", $elementToAdd->{nodes}, $nodeHash ) );

                            if ( defined( $tags ) ) {
                                push( @$storage, $toAdd );
                            }
                            else {
                                $wayHash->{$toAdd->{id}} = $toAdd;
                            }
                            #print STDERR "Will add way ", HK::BaseUtils::hashReferenceToString($toAdd), "\n";
                        }
                        else {
                            warn "Could not find referenced node for $first. So this entry is skipped\n";
                        }
                    }
                    else {
                        my $toAdd = _createElasticsearchDocument( $nodeHash, $snapshotDay, $elementType, $elementToAdd, undef, undef, _buildShape( "LineString", $elementToAdd->{nodes}, $nodeHash ) );
                        #print STDERR "Will add way as linestring ", HK::BaseUtils::hashReferenceToString($toAdd), "\n";
                        if ( defined( $tags ) ) {
                            push( @$storage, $toAdd );
                        }
                        else {
                            $wayHash->{$toAdd->{id}} = $toAdd;
                        }
                    }
                }
            }
        }
        
    }

    #print $elementToAdd->{id}, "\n";
}
#############################################################################
sub _buildShape {
    my( $type, $arrayRefOfNodeIds, $nodeHash ) = @_;

    my @coordinates = ();
    foreach my $nodeId ( @$arrayRefOfNodeIds ) {
        if ( defined( $nodeHash->{$nodeId} ) ) {
            push( @coordinates, [ $nodeHash->{$nodeId}->{lon}+0, $nodeHash->{$nodeId}->{lat}+0 ] );
        }
    }

    if ( @coordinates > 1 ) {
        my $result = undef;
        if ( lc($type) eq "polygon" ) {
            $result = { "type" => $type, "coordinates" => [ \@coordinates ] };
        }
        if ( lc($type) eq "linestring" ) {
            $result = { "type" => $type, "coordinates" => \@coordinates };
        }
        #print STDERR Dumper( $result );
        return( $result );
    }
    return( undef );
}
#############################################################################
sub _createElasticsearchDocument {
    my( $nodeHash, $snapshotDay, $elementType, $elementToAdd, $latitude, $longitude, $complexGeolocation ) = @_;
    my $tags = $elementToAdd->{tags};
    my $elasticsearchStructure = dclone( $tags ); # we start with all the tag values as fields
    $elasticsearchStructure->{snapshotDay} = $snapshotDay;
    $elasticsearchStructure->{timestamp} = $elementToAdd->{timestamp};
    $elasticsearchStructure->{user} = $elementToAdd->{user};
    $elasticsearchStructure->{id} = $elementType . "_" . $elementToAdd->{id} . "_" . $snapshotDay;

    if ( defined( $latitude ) and defined( $longitude ) ) {
        if ( defined( $complexGeolocation ) ) {
            $elasticsearchStructure->{geolocation} = $complexGeolocation;
        }
        else {
            $elasticsearchStructure->{geolocation} = { "type" => "point", "coordinates" => [ $longitude, $latitude ] };
        }
        $elasticsearchStructure->{geolocation_as_point} = { lon => $longitude, lat => $latitude };
    }
    else {
        if ( defined( $complexGeolocation ) ) {
            $elasticsearchStructure->{geolocation} = $complexGeolocation;
        }
    }

    #print STDERR "Created ", HK::BaseUtils::hashReferenceToString($tags), "\n";
    return( $elasticsearchStructure );
}

#############################################################################
sub getUsageString {
    my $errorString = <<"EOTEXT";

Options: [--snapshotDay <dateSpec>] <osmJsonFile>
Insert the named nodes and ways contained in the user specified osm data json file into an elasticsearch index.

The snapshot day must be specified in format yyyy-MM-dd. Default is today.

Note: download data via overpass api e.g. like this:
  curl --output kaiserslauternAllNodes_`date "+%Y-%m-%d"`.json  -X POST 'https://overpass-api.de/api/interpreter' -d '<osm-script output="json"><union><bbox-query s="49.3670" w="7.6220" n="49.5036" e="7.8941"/><recurse type="up"/></union><print mode="meta"/></osm-script>'

Sample call:
  $0 --inputDataType json --blockSize 1000000 --dataIsInField "elements" --elasticsearchUrl http://localhost:9200 --indexName kaiserslautern_openstreetmap ~/kaiserslauternAllNodes_2023-04-11.json

EOTEXT
    return( $errorString );
}
#############################################################################
sub checkCommandLine {

    my ( $snapshotDay, $elasticsearchManager, $genericImporter ) = @_;
    
    # Note: since we check the commandline via checkCommandlineAndInitSeveralParameterManagers any -h or --help will be gone afterwards
    #       So we check here for a help flag, so we can act correctly afterwards
    my $helpMe = HK::BaseUtils::isHelpFlagInArray( @ARGV );
    my( $managerCheckWasSuccessful, $errorString ) = HK::BaseUtils::checkCommandlineAndInitSeveralParameterManagers( \@ARGV, 0, undef, $elasticsearchManager, $genericImporter );
    my $explicitError = "";

    # From now on we should give an error, if an unknown option is found
    Getopt::Long::Configure( "no_pass_through" );

    # Check command line
    if ( GetOptionsFromArray(  \@ARGV,
                               "snapshotDay=s" => $snapshotDay,
                               "h" => \$helpMe, "help" => \$helpMe ) ) {
        # okay
	unless( defined( $$snapshotDay ) ) {
	    my $now = localtime;
	    $$snapshotDay = $now->ymd();  # year-month-day
	}
    }
    else {
      $helpMe = 1;
    }
    
    if ( $helpMe or ! $managerCheckWasSuccessful ) {
        my $usage = getUsageString();
        die "$errorString\n$usage\n$explicitError\n";
    }
}
