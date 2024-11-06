#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
use Carp;
use Try::Tiny;

use FindBin qw($RealBin);
use lib ( "$RealBin/../lib", "$RealBin/../libAloeEcosystem" );

use Text::Levenshtein qw(distance);

use HK::BaseUtils;
use HK::ImportParameterManager;
use HK::GenericImporter;
use HK::ElasticsearchManager;

use utf8;
use open qw(:std :utf8);

main();

#############################################################################
sub getUsageString {
    my $errorString = <<"EOTEXT";

Process the content of a car registration csv file and write the corresponding data to an elasticsearch index
using the index specified by the XXXWrite parameters. Before the data is written, it is tried to enhance
the correctness of specified address data by lookups to an index containing the (fix vocabulary of) street names.
The latter index is specified by the XXXStreetInfo parameters. This index also used to translate the sensitive
address data into ids of suburbs and statistical regions

Please note that the comment field of the index still might contain some sensitive data fragments, so use with care.

Sample call:
 $0 --inputDataType csv --separatorCharacter ";" --blockSize 100000 ~/Projects/stadtKl/Kfz/myFile.csv --elasticsearchUrlStreetInfo http://localhost:9200 --indexNameStreetInfo kaiserslautern_addresses_to_shapes_and_location --elasticsearchUrlWrite http://localhost:9200 --indexNameWrite kaiserslautern_kfz

EOTEXT
    return( $errorString );
}

#############################################################################
sub checkCommandLine {

    my ( $highLevelManagersArrayRef ) = @_;
    my( $managerCheckWasSuccessful, $errorString );
    
    # Note: since we check the commandline via checkCommandlineAndInitSeveralParameterManagers any -h or --help will be gone afterwards
    #       So we check here for a help flag, so we can act correctly afterwards
    my $helpMe = HK::BaseUtils::isHelpFlagInArray( @ARGV );
    if ( @$highLevelManagersArrayRef > 0 ) {
        ( $managerCheckWasSuccessful, $errorString ) = HK::BaseUtils::checkCommandlineAndInitSeveralParameterManagers( \@ARGV, 0, undef, @$highLevelManagersArrayRef );
    }
    my $explicitError = "";

    # From now on we want to fail if we detect invalid options
    Getopt::Long::Configure( 'no_pass_through' );
    
    if ( GetOptionsFromArray( \@ARGV,
                              #"populationReferenceYear=i" => $populationReferenceYear,
                              #"datenstandFile=s" => \@datenstandValueFiles,
                              "h" => \$helpMe, "help" => \$helpMe ) ) {
        # okay
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
sub main {
    my $genericImporter = HK::GenericImporter->new();
    my $elasticsearchManagerStreet = HK::ElasticsearchManager->new( "namespace" => "StreetInfo" );
    my $elasticsearchManagerWrite = HK::ElasticsearchManager->new( "namespace" => "Write" );

    checkCommandLine( [ $genericImporter, $elasticsearchManagerStreet, $elasticsearchManagerWrite ] );

    my %toFillStreetAndNumber = ();
    my %toFillStreetOnly = ();
    $elasticsearchManagerStreet->sendHttpPostRequestAndIterateOnResultWithPaging( 5000, "2m", "_doc", undef, sub { preprocess( \%toFillStreetAndNumber, \%toFillStreetOnly, @_ ); } );

    #my @addedKeys = keys( %toFill );
    #my $length = @addedKeys;
    #print STDERR "Got $length keys\n";
    #my $value = $toFill{"Aalstraße_1"};
    #print STDERR "Got stat: ", $value->{statId}, ", suburb: ", $value->{suburbId}, "\n";

    my $storage = [];   # array reference
    $genericImporter->addHandler( sub { writeToElasticsearch( $storage, \%toFillStreetAndNumber, \%toFillStreetOnly, $elasticsearchManagerWrite, $elasticsearchManagerStreet, @_ ); } );
    $genericImporter->startProcessing();
    if ( @$storage > 0 ) {
        $elasticsearchManagerWrite->addSeveralPerlStructuresWithAutomaticIdsViaBulk( $storage );
	print STDERR "Added final " . @$storage . " units of data\n";
    }
}
#############################################################################
sub writeToElasticsearch {
    my ( $storage, $streetAndNumberHash, $streetHash, $elasticsearchManagerWrite, $elasticsearchManagerStreet, $inputObject ) = @_;


    if ( HK::BaseUtils::isNotEmpty($inputObject->{"Anrede"}) ) {
        my $maxInserts = 10000;
        if ( @$storage > 0 && @$storage % $maxInserts == 0 ) {
            my $e;
            try {
                $elasticsearchManagerWrite->addSeveralPerlStructuresWithAutomaticIdsViaBulk( $storage );
                @$storage = ();
            }
            catch {
                die "Got error $_\n";
            }
        }
        
        my $elasticsearchStructure = {};
        $elasticsearchStructure->{car_registration_prefix} = $inputObject->{"Kennzeichen"};
        $elasticsearchStructure->{car_form_of_address} = $inputObject->{"Anrede"};
        $elasticsearchStructure->{car_domicile} = $inputObject->{"Wohnort"};
        $elasticsearchStructure->{car_postcode} = $inputObject->{"Postleitzahl"};
        $elasticsearchStructure->{car_usage} = $inputObject->{"Fahrzeugverwendung"};
        my $erstzulassung = $inputObject->{"Erstzulassung"};
        if ( defined( $erstzulassung ) && $erstzulassung =~ m/^\d{8}$/ ) {
            $elasticsearchStructure->{license_date} = $erstzulassung;
        }
        $elasticsearchStructure->{car_class_key} = $inputObject->{"Schl. Fahrzeugklasse"};
        $elasticsearchStructure->{car_emi_class_key} = $inputObject->{"Schl. EMI-Klasse"};
        $elasticsearchStructure->{car_emi_class_nat} = $inputObject->{"nat. EMI-Klasse"};
        $elasticsearchStructure->{car_fuel_type_key} = $inputObject->{"Schl. Kraftstoff"};
        $elasticsearchStructure->{car_type_key} = $inputObject->{"Schl. Typ"};
        $elasticsearchStructure->{car_version_key} = $inputObject->{"Schl. Variante/Version"};
        $elasticsearchStructure->{car_manufacturer_key} = $inputObject->{"Schl. Hersteller"};
        $elasticsearchStructure->{car_manufacturer_text} = $inputObject->{"Text Hersteller"};
        $elasticsearchStructure->{car_composition_key} = $inputObject->{"Schl. Aufbauart"};
        $elasticsearchStructure->{car_composition_text} = $inputObject->{"Text Aufbauart"};

        $elasticsearchStructure->{STAT_BEZ} = $inputObject->{"id_statistical_region"};
            
        my $nameToUse = undef;
        if ( _isProbablyKaiserslautern( $elasticsearchStructure->{car_domicile} ) ) {
            $nameToUse = makeStreetNameProposal( $inputObject->{"Straße"}, $streetHash, $elasticsearchManagerStreet, $elasticsearchStructure );
        }
        if ( defined( $nameToUse ) ) {
            #print $inputObject->{"Straße"}, "  ==> '$nameToUse'\n";
            
            my $addressInfoKey = $nameToUse . "_" . $inputObject->{"Hausnummer"};
            my $entry = $streetAndNumberHash->{$addressInfoKey};
            if ( defined( $entry ) ) {
                $elasticsearchStructure->{id_statistical_region} = $entry->{statId};
                $elasticsearchStructure->{id_suburb} = $entry->{suburbId};
                #print "Found entry for $addressInfoKey\n";
            }
            else {
                _addComment( "Could not find statistical region or suburb for address '$addressInfoKey'", $elasticsearchStructure );
                #warn "Could not find statistical region or suburb for address $addressInfoKey\n";
            }
        }

        
        push( @$storage, $elasticsearchStructure );
    }
    
}
#############################################################################
sub _isProbablyKaiserslautern {
    my( $toCheck ) = @_;
    return( $toCheck =~ m/^\s*(Ka.*autern)\s*$/i or
            $toCheck =~ m/^\s*Kaiserslau/i or
            $toCheck =~ m/^\s*(Kaiserslautern|Kaisersl\.|Kaisers[.*]*ern|Kaiserslaute)\s*$/i or
            $toCheck =~ m/^\s*Kaiserslautern/i or  # maybe with suburb: Kaiserslautern OT Morlautern
            $toCheck =~ m/^\s*Kaisersl\.\-/i );
}
#############################################################################
sub _addComment {
    my( $newComment, $elasticsearchStructure ) = @_;

    my $toExtend = exists( $elasticsearchStructure->{comment} ) ? $elasticsearchStructure->{comment} . "\n" : "";
    $toExtend .= $newComment;

    $elasticsearchStructure->{comment} = $toExtend;
}

#############################################################################
sub makeStreetNameProposal {
    my( $streetName, $streetHash, $elasticsearchManagerStreet, $elasticsearchStructure ) = @_;
    my $streetNameToUse = lc($streetName);

    if ( defined( $streetHash->{$streetNameToUse} ) ) {
        return( $streetNameToUse );
    }
    else {
        $streetNameToUse =~ s/str\./straße/i;
        $streetNameToUse =~ s/\s*\-\s*/-/;
        $streetNameToUse =~ s/str$/straße/i;
        $streetNameToUse =~ s/strasse/straße/i;
        $streetNameToUse =~ s/schlößchen/schlösschen/i;
        $streetNameToUse =~ s/schloß/schloss/i;
        if ( defined( $streetHash->{$streetNameToUse} ) ) {
            #_addComment( "Street name was postprocessed: $streetName -> $streetNameToUse", $elasticsearchStructure );
            return( $streetNameToUse );
        }
        else {
            print "Search by query: ";
            my @resultFuzzy = ();
            my %markerFuzzy = ();
            # get proposals via elasticsearch
            my $queryFuzzy = { "size" => 25, "query" => { "fuzzy" => {"street_name" => { "value" => $streetNameToUse, "fuzziness" => 2 }}}};
            #my $queryFuzzy = { "size" => 25, "query" => { "match" => { "street_name" => { "query" => $streetNameToUse, "fuzziness" => 2 }}}};
            $elasticsearchManagerStreet->sendHttpPostRequestAndIterateOnResult( "_search?pretty", $queryFuzzy, sub { ngramHandler(\@resultFuzzy, \%markerFuzzy, "fuzzy", @_); }, "hits:hits" );

            my @resultNgram = ();
            my %markerNgram = ();
            #if ( @result < 5 ) {
            %markerNgram = ();
            my $queryNgram = { "size" => 25, "query" => { "match" => {"street_name.ngram" => $streetNameToUse }}};
            $elasticsearchManagerStreet->sendHttpPostRequestAndIterateOnResult( "_search?pretty", $queryNgram, sub { ngramHandler(\@resultNgram, \%markerNgram, "ngram", @_); }, "hits:hits" );

            if ( @resultNgram > 0 && @resultFuzzy > 0 ) {
                my $firstPlausibleFuzzy = getFirstPlausible( $streetNameToUse, @resultFuzzy );
                my $firstPlausibleNgram = getFirstPlausible( $streetNameToUse, @resultNgram );
                if (  defined($firstPlausibleFuzzy) and defined($firstPlausibleNgram) ) {
                    if ( $firstPlausibleFuzzy eq $firstPlausibleNgram ) {
                        _addComment( "Street name was postprocessed: fuzzy and ngram did yield a common first result: '$streetNameToUse' -> $firstPlausibleFuzzy", $elasticsearchStructure );
                        return( $firstPlausibleFuzzy );
                    }
                    else {
                        my @sortedFuzzy = sortByLevenshteinDistance( $streetNameToUse, @resultFuzzy );
                        my @sortedNgram = sortByLevenshteinDistance( $streetNameToUse, @resultNgram );
                        if ( $sortedFuzzy[0] eq $sortedNgram[0] ) {
                            _addComment( "Street name was postprocessed: fuzzy and ngram did yield a common result with least Levenshtein distance: '$streetNameToUse' -> " . $sortedFuzzy[0], $elasticsearchStructure );
                            #print "Levenshtein chose the following candidate for '$streetNameToUse': ", $sortedFuzzy[0], "\n";
                            return( $sortedFuzzy[0] );
                        }
                        elsif ( distance( $streetNameToUse, $sortedNgram[0] ) <= 1 ) {
                            _addComment( "Street name was postprocessed: ngram did yield a plausible result with Levenshtein distance <= 1: '$streetNameToUse' -> " . $sortedNgram[0], $elasticsearchStructure );
                            #print "Very similar candidate found by ngram for '$streetNameToUse'  ==> ", $sortedNgram[0], "\n";
                            return( $sortedNgram[0] );
                        }
                        elsif ( distance( $streetNameToUse, $sortedFuzzy[0] ) <= 1 ) {
                            _addComment( "Street name was postprocessed: fuzzy did yield a plausible result with Levenshtein distance <= 1: '$streetNameToUse' -> " . $sortedFuzzy[0], $elasticsearchStructure );
                            #print "Very similar candidate found by ngram for '$streetNameToUse'  ==> ", $sortedNgram[0], "\n";
                            return( $sortedFuzzy[0] );
                        }
                    }
                }
                else {
                    my $comment = "No plausible candidate found for '$streetNameToUse'  ==> ";
                    $comment .= "**Ngram: " . join (", ", @resultNgram);
                    $comment .= "     **Fuzzy: " . join (", ", @resultFuzzy);
                    _addComment( $comment, $elasticsearchStructure );
                }
            }
            elsif ( @resultNgram > 0 ) {
                my @sortedNgram = sortByLevenshteinDistance( $streetNameToUse, @resultNgram );
                if ( distance( $streetNameToUse, $sortedNgram[0] ) <= 3 ) {
                    _addComment( "Street name was postprocessed: only ngram did yield a result with small Levenshtein distance (<=3): '$streetNameToUse' -> " . $sortedNgram[0], $elasticsearchStructure );
                    return( $sortedNgram[0] );
                    print "Plausible candidate found only by ngram for '$streetNameToUse'  ==> ", $sortedNgram[0], "\n";
                }
                else {
                    _addComment( "Proposals for '$streetNameToUse' only found by ngram but least Levenshtein distance was " . distance( $streetNameToUse, $sortedNgram[0] ), $elasticsearchStructure );
                    print "Ngram only failed for $streetNameToUse. Best match was ", $sortedNgram[0], " with distance ", distance( $streetNameToUse, $sortedNgram[0] ), "\n";
                }
            }
            elsif ( @resultFuzzy > 0 ) {
                my @sortedFuzzy = sortByLevenshteinDistance( $streetNameToUse, @resultFuzzy );
                if ( distance( $streetNameToUse, $sortedFuzzy[0] ) <= 3 ) {
                    _addComment( "Street name was postprocessed: only fuzzy did yield a result with small Levenshtein distance (<=3): '$streetNameToUse' -> " . $sortedFuzzy[0], $elasticsearchStructure );
                    return( $sortedFuzzy[0] );
                    print "Plausible candidate found only by fuzzy for '$streetNameToUse'  ==> ", $sortedFuzzy[0], "\n";
                }
                else {
                    _addComment( "Proposals for '$streetNameToUse' only found by fuzzy but least Levenshtein distance was " . distance( $streetNameToUse, $sortedFuzzy[0] ), $elasticsearchStructure );
                    print "Fuzzy only failed for '$streetNameToUse'. Best match was ", $sortedFuzzy[0], " with distance ", distance( $streetNameToUse, $sortedFuzzy[0] ), "\n";
                }
            }
            else {
                print "No ngram results for '$streetNameToUse'\n" unless @resultNgram > 0;
                print "No fuzzy results for '$streetNameToUse'\n" unless @resultFuzzy > 0;
            }
            

            _addComment( "Street name '$streetName' ('$streetNameToUse') could not be mapped", $elasticsearchStructure );
            print "Mapping failure: $streetName ($streetNameToUse) could not be mapped\n";
            return( undef );
        }
    }
}

#############################################################################
sub sortByLevenshteinDistance {
    my ( $originalName, @guesses ) = @_;
    my @distances = distance( $originalName, @guesses );
    my @objects = ();
    for( my $i = 0; $i < @distances; $i++ ) {
        my $newElement = { "word" => $guesses[$i], "distance" => $distances[$i] };
        push( @objects, $newElement );
    }
    my @sortedObjects = sort {$a->{distance} <=> $b->{distance}} @objects;

    return( map { $_->{word} } @sortedObjects );
}
#############################################################################
sub getFirstPlausible {
    my ( $originalName ) = shift;
    my $firstPlausible = undef;

    if ( defined( $originalName ) and length( $originalName ) > 0 ) {
        my $firstLetter = substr( $originalName, 0, 1 );
        foreach my $member ( @_ ) {
            if ( $member =~ m/^$firstLetter/i ) {
                $firstPlausible = $member;
                last;
            }
        }
    }

    return( $firstPlausible );
}
#############################################################################
sub ngramHandler {
    my ( $storeHere, $marker, $prefix, $resultArray ) = @_;

    if ( @$storeHere < 5 ) {
        #my $key = "($prefix) " . $resultArray->{_source}->{street_name};
        my $key = lc($resultArray->{_source}->{street_name});
        if ( ! defined( $marker->{$key} ) ) {
            $marker->{$key} = 1;
            my $proposal = $key;
            push( @$storeHere, $proposal );
        }
    }
}
#############################################################################
sub normalizeStreetName {
    my( $streetName ) = @_;
    $streetName =~ s/str\./straße/i;
    $streetName =~ s/\s*\-\s*/-/;
    $streetName =~ s/str$/straße/i;
    $streetName =~ s/strasse/straße/i;
    $streetName =~ s/schlößchen/schlösschen/i;
    $streetName =~ s/schloß/schloss/i;
    return( lc($streetName) );
}

#############################################################################
sub preprocess {
    my ( $streetAndNumberHash, $streetHash, $inputObject ) = @_;
    my $key = lc($inputObject->{street_name}) . "_" . $inputObject->{house_number};
    if ( defined( $inputObject->{house_number_addition} ) ) {
        $key .= "_" . $inputObject->{house_number_addition};
    }
    $streetHash->{lc($inputObject->{street_name})} = $inputObject->{street_name};
    $streetAndNumberHash->{$key} = { "statId" => $inputObject->{id_statistical_region}, suburbId =>  $inputObject->{id_suburb} };
    print "Added entry for $key\n";
}
