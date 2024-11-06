#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case :config pass_through);

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

Options: [--fieldSpec <fieldInFile|fieldInIndex>]* [--pointSpec <fieldLatitudeInFile|fieldLongitudeInFile|fieldInIndex>]*  [--staticField <fieldInIndex|valueInIndex>]* [--mapToEmpty <fieldInFile|valueToMapToEmpty>]* [idFieldCombination=<elasticName|fieldName|...|fieldName>] [--filterCommand <optionalFilterCommand>] [--command <optionalCommand>]

An import script for simple CSV or JSON files to be imported as is (that is: without further preprocessing).

A field specification contains the field name in the file and the field name in the index separated by a pipe symbol.
A static field contains the field name in the index and its static value separated by a pipe symbol. Specifying
several static fields with same value for fieldInIndex will result in an array of values stored for the specified
field.
A point specification will add the fields <fieldInIndex> and <fieldInIndex_as_point> as geo_shape and geo_point
respectively. The fields are expected to be specified separated by a pipe symbol. Latitude and longitude values
 are extracted from the specified <fieldLatitudeInFile> and <fieldLongitudeInFile>.

Combinations of 'key|value' in mapToEmpty will cause the corresponding entry in the file NOT to be mapped to the
corresponding elasticsearch field (which will be left unset instead)

If option --idFieldCombination is specified, a combination of the values in the specified fields is used as the id for a document inserted into elasticsearch index. The value is also stored in the elastic field 'elasticName' (this is needed for technical reasons since the documents are added blockwise).

If option --command is specified, the corresponding parameter will be evaluated in the method called for data processing, after
processing the field specifications and other optional parameters. You can use variable \$elasticsearchStructure, to access
the elasticsearch structure just before being sent to elasticsearch (or: getting stored for this purpose).

If option --filterCommand is specified, the corresponding parameter will be evaluated in the method called for data processing, before
processing the field specifications and other optional parameters. If the evaluated expression returns 0 the structure is not processed
(and thus not added to the index). You can use variable \$elementToAdd, to access the incoming data.

Please note, that it is needed to specify option -CA to the call if the specified options contain special characters like umlaute.

Sample call csv:
  perl -CA $0 --inputDataType csv --separatorCharacter ";" --blockSize 10000 --fieldSpec 'Datum|Datum' --fieldSpec 'Arbeitslose|Arbeitslose' --fieldSpec 'Pressure|PressureScore'  --staticField 'Typ|arbeitslose' --elasticsearchUrl http://localhost:9200 --indexName pandemic_pressure_score /some/where/Arbeitslose.csv
  perl -CA $0 --inputDataType csv --separatorCharacter ";" --blockSize 10000 --fieldSpec 'date|Datum' --fieldSpec 'Belegte Betten|BelegteBetten' --fieldSpec 'Freie Betten|FreieBetten'  --fieldSpec '% Auslastung|Auslastung'  --staticField 'Typ|auslastungIntensivbetten' --elasticsearchUrl http://localhost:9200 --indexName pandemic_pressure_score /some/where/AuslastungIntensivbetten.csv
  perl -CA $0 --blockSize 20000 --inputDataType csv --inputDataEncoding utf8 --fieldSpec "altLabel|name" --fieldSpec "prefLabel|rdfLabel" --staticField "origin|https://www.dcat-ap.de/def/politicalGeocoding/regionalKey/20220331.rdf" --idFieldCombination "id|identifier" --elasticsearchUrl http://localhost:9200 --indexName dcat_regional_keys /some/where/regionalKeys.csv
  perl -CA $0 --inputDataType csv --separatorCharacter ";" --blockSize 1000000 --fieldSpec "ta_nummer|tree_type_id" --pointSpec "latitude|longitude|geolocation" --staticField "import_date|"`date "+%Y-%m-%d"` --elasticsearchUrl http://localhost:9200 --indexName kaiserslautern_baum_kataster /some/where/Baumstandorte_KL_epsg4326.csv
  perl -CA $0 --inputDataType csv --separatorCharacter ";" --blockSize 10000 --fieldSpec "CL_STR_KEY|street_id" --fieldSpec "Strasse|street_name" --fieldSpec "HNR|house_number" --fieldSpec "Zusatz|house_number_addition" --fieldSpec "CL-Stat_Bez|id_statistical_region" --staticField "import_date|"`date "+%Y-%m-%d"` --pointSpec "lat|lon|geolocation" --mapToEmpty "Zusatz|NULL" --command '\$elasticsearchStructure->{id_suburb} = substr( \$elasticsearchStructure->{id_statistical_region}, 0, 2 );' --blockSize 100000 --elasticsearchUrl http://localhost:9200 --indexName kaiserslautern_addresses_to_shapes_and_location ~/Projects/ElasticsearchData/PublicElastic/tmp/Kosis/ST_STR_HNR_STATBEZ_epsg4326.csv
  perl -CA ~/bin/AloeEcosystemTools/bin/fileDataToElasticsearchGeneric.pl --inputDataType json --blockSize 1000000 --dataIsInField "elements" --fieldSpec "id|id" --pointSpec "lat|lon|geolocation" --elasticsearchUrl http://localhost:9200 --indexName kaiserslautern_openstreetmap_just_nodes --filterCommand 'return(0) if ( (not \$elementToAdd->{type}) or (lc(\$elementToAdd->{type}) ne "node")); return(1);' --idFieldCombination 'id|id' ~/kaiserslauternAllNodes_2023-04-11.json
EOTEXT
    return( $errorString );
}
#############################################################################
sub main {
    my $genericImporter = HK::GenericImporter->new();
    my $elasticsearchManager = HK::ElasticsearchManager->new();
    
    my @fieldSpecifications = ();
    my @pointSpecifications = ();
    my @staticFields = ();
    my %mapOfValuesToTreatAsEmpty = ();
    my %idFieldCombination;
    my $optionalCommand;
    my $optionalFilterCommand;
    checkCommandLine( $elasticsearchManager, $genericImporter, \@fieldSpecifications, \@pointSpecifications, \@staticFields, \%idFieldCombination, \%mapOfValuesToTreatAsEmpty, \$optionalFilterCommand, \$optionalCommand );

    my $storage = [];   # array reference
    my $timestamp = time();
    $genericImporter->addHandler( sub { handleOneInputRow( $storage, $timestamp, $elasticsearchManager, \@fieldSpecifications,
                                                           \@pointSpecifications, \@staticFields, \%idFieldCombination, \%mapOfValuesToTreatAsEmpty, $optionalFilterCommand, $optionalCommand, @_ ); } );
    $genericImporter->startProcessing();
    
    if ( @$storage > 0 ) {
        uploadToElasticsearch( $elasticsearchManager, $storage, \%idFieldCombination );
	print STDERR "Added final " . @$storage . " units of data\n";
    }
}
#############################################################################
sub checkCommandLine {

    my ( $elasticsearchManager, $genericImporter, $fieldSpecifications, $pointSpecifications, $staticFields, $idFieldCombination, $mapOfValuesToTreatAsEmpty, $optionalFilterCommand, $optionalCommand ) = @_;
    
    # Note: since we check the commandline via checkCommandlineAndInitSeveralParameterManagers any -h or --help will be gone afterwards
    #       So we check here for a help flag, so we can act correctly afterwards
    my $helpMe = HK::BaseUtils::isHelpFlagInArray( @ARGV );
    my( $managerCheckWasSuccessful, $errorString ) = HK::BaseUtils::checkCommandlineAndInitSeveralParameterManagers( \@ARGV, 0, undef, $elasticsearchManager, $genericImporter );
    my $explicitError = "";


    # Check command line
    my @rawFields = ();
    my @rawPoints = ();
    my @rawStaticFields = ();
    my @fieldsToMapToEmptyRaw = ();
    my $idFieldCombinationString;

    if ( GetOptionsFromArray( \@ARGV,
                              "fieldSpec=s" => \@rawFields,
                              "pointSpec=s" => \@rawPoints,
                              "staticField=s" => \@rawStaticFields,
                              "mapToEmpty=s" => \@fieldsToMapToEmptyRaw,
                              "idFieldCombination=s" => \$idFieldCombinationString,
                              "filterCommand=s" => $optionalFilterCommand,
                              "command=s" => $optionalCommand,
                              "h" => \$helpMe, "help" => \$helpMe ) ) {
        # okay
        if ( @rawFields == 0 ) {
            $explicitError = "** Please specify at least one field to extract";
            $helpMe = 1;
        }
        elsif ( ! $elasticsearchManager->isIndexChosen() ) {
            $explicitError = "** Please choose an index via commandline parameter";
            $helpMe = 1;
        }
        else {
            foreach my $fieldSpecification ( @rawFields ) {
                my( $fieldNameInData, $fieldNameInIndex ) = split( /\|/, $fieldSpecification );
                push( @$fieldSpecifications, { "fieldNameInData" => $fieldNameInData, "fieldNameInIndex" => $fieldNameInIndex } );
            }
            foreach my $pointField ( @rawPoints ) {
                my( $latitude, $longitude, $fieldNameInIndex ) = split( /\|/, $pointField );
                push( @$pointSpecifications, { "fieldNameInIndex" => $fieldNameInIndex, "latitudeFieldName" => $latitude, "longitudeFieldName" => $longitude } );
            }
            foreach my $staticField ( @rawStaticFields ) {
                my( $fieldNameInIndex, $valueInIndex ) = split( /\|/, $staticField );
                push( @$staticFields, { "fieldNameInIndex" => $fieldNameInIndex, "valueInIndex" => $valueInIndex } );
            }
            foreach my $emptyField ( @fieldsToMapToEmptyRaw ) {
                my( $fieldNameInFile, $valueToMapToZero ) = split( /\|/, $emptyField );
                $mapOfValuesToTreatAsEmpty->{$fieldNameInFile} = {} unless exists( $mapOfValuesToTreatAsEmpty->{$fieldNameInFile} );
                $mapOfValuesToTreatAsEmpty->{$fieldNameInFile}->{$valueToMapToZero} = 1;
            }
            
            if ( defined( $idFieldCombinationString ) ) {
                my @parts = split( /\|/, $idFieldCombinationString );
                my $newIdName = shift( @parts );
                %$idFieldCombination = ( id => $newIdName, fields => \@parts );
            }
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
#############################################################################
sub uploadToElasticsearch {
    my( $elasticsearchManager, $storage, $idFieldCombination ) = @_;
    
    if ( keys (%$idFieldCombination) > 0 ) {
        $elasticsearchManager->addSeveralPerlStructuresWithExpliciteIdsViaBulk( $idFieldCombination->{id}, $storage );
	print STDERR "Added " . @$storage . " units of data with explicite ids\n";
    }
    else {
        $elasticsearchManager->addSeveralPerlStructuresWithAutomaticIdsViaBulk( $storage );
	print STDERR "Added " . @$storage . " units of data with automatic ids\n";
    }
}

#############################################################################
# Add several values, if static key is specified more than once
sub handleOneOrMoreOccurrencesOfStaticFields {
    my( $elasticsearchStructure, $staticFieldsArrayRef ) = @_;

    my %keyHash = ();

    foreach my $staticField ( @$staticFieldsArrayRef ) {
        my $key = $staticField->{"fieldNameInIndex"};
        my $value = $staticField->{"valueInIndex"};

        $keyHash{$key} = [] unless exists( $keyHash{$key} );
        push( @{ $keyHash{$key} }, $value );
    }

    foreach my $key ( keys %keyHash ) {
        my $values = $keyHash{$key};
        if ( @$values > 1 ) {
            $elasticsearchStructure->{$key} = $values;
        }
        else {
            $elasticsearchStructure->{$key} = $values->[0];
        }
    }
}
#############################################################################
sub handlePointSpecifications {
    my( $elasticsearchStructure, $dataHash, $pointSpecificationsArrayRef ) = @_;
    
    foreach my $pointSpecification ( @$pointSpecificationsArrayRef ) {
        # keys: fieldNameInIndex latitudeFieldName longitudeFieldName
        my $latitude = $dataHash->{$pointSpecification->{"latitudeFieldName"}} + 0;
        my $longitude = $dataHash->{$pointSpecification->{"longitudeFieldName"}} + 0;
        my $geometryName = $pointSpecification->{"fieldNameInIndex"};
        my $geometryAsPoint = $pointSpecification->{"fieldNameInIndex"} . "_as_point";
        
        $elasticsearchStructure->{$geometryName} = { "type" => "Point", "coordinates" => [ $longitude, $latitude ] };
        $elasticsearchStructure->{$geometryAsPoint} = { lon => $longitude, lat => $latitude };
    }
}

#############################################################################

# Note: hook should return number of elements processed (used to avoid system overload)?
sub handleOneInputRow {
    my( $storage, $timestamp, $elasticsearchManager, $fieldSpecifications, $pointSpecifications, $staticFields, $idFieldCombination, $mapOfValuesToTreatAsEmpty,
        $optionalFilterCommand, $optionalCommand, $elementToAdd, $importParameterManager ) = @_;

    
    my $maxInserts = 10000;
    if ( @$storage > 0 && @$storage % $maxInserts == 0 ) {
        uploadToElasticsearch( $elasticsearchManager, $storage, $idFieldCombination );
	@$storage = ();
    }

    my $isToBeProcessed = 1;
    if ( defined( $optionalFilterCommand ) ) {

        #OKAY: $isToBeProcessed = 0 if ( (not $elementToAdd->{type}) or (lc($elementToAdd->{type}) ne "node"));
        $isToBeProcessed = eval $optionalFilterCommand;
    }

    if ( $isToBeProcessed ) {
        my $elasticsearchStructure = {};
        my %inserted = ();
        foreach my $fieldSpecification ( @$fieldSpecifications ) {
            my $valueToInsert = $elementToAdd->{$fieldSpecification->{"fieldNameInData"}};
            if ( not exists( $mapOfValuesToTreatAsEmpty->{$fieldSpecification->{"fieldNameInData"}}->{$valueToInsert} ) ) {
                $elasticsearchStructure->{$fieldSpecification->{"fieldNameInIndex"}} = $valueToInsert;
                $inserted{$fieldSpecification->{"fieldNameInIndex"}} = 1;
            }
        }

        handlePointSpecifications( $elasticsearchStructure, $elementToAdd, $pointSpecifications );

        handleOneOrMoreOccurrencesOfStaticFields( $elasticsearchStructure, $staticFields );
        #foreach my $staticField ( @$staticFields ) {
        #    $elasticsearchStructure->{$staticField->{"fieldNameInIndex"}} = $staticField->{"valueInIndex"};
        #}

        ### should we add a timestamp of the import process? I think we will skip that
        #print Dumper( $elasticsearchStructure );
        #if ( not exists( $inserted{"creationDate"} ) ) {
        #    $elasticsearchStructure->{"creationDate"} = $timestamp;
        #}

        if ( keys (%$idFieldCombination) > 0 ) {
            my $value = "";
            foreach my $oneField ( @{ $idFieldCombination->{fields} } ) {
                $value .= "_" unless $value eq "";
                $value .= $elementToAdd->{$oneField};
            }
            $elasticsearchStructure->{$idFieldCombination->{id}} = $value;
        }

        if ( defined( $optionalCommand ) ) {
            eval $optionalCommand;
        }

        push( @$storage, $elasticsearchStructure );

        #print Dumper( $elementToAdd );
    }
}





