package HK::BaseUtils;

use strict;
use warnings;
use Carp;
use utf8;  # we have umlaute in our source code

use Encode;
use POSIX;
use JSON::XS;

use DateTime::Format::Strptime;
use Time::Local;

use Unicode::Normalize;
use File::Temp qw(:POSIX);

use Term::ReadKey;

# hk: no longer needed?
#use DateTime::Format::DateParse;

# To export only selected functions (or variables), we derive
# from class 'Exporter', so the user can call method 'import()'
# of class 'Exporter'
use Exporter;
our @ISA = ( 'Exporter' );
# which functions to export by default?
our @EXPORT = qw(isHelpFlagInArray);
# which functions to export byuser request?
our @EXPORT_OK = qw(isNotEmpty spaceCleanup isEmpty convertKeywordStringToAloeStyle cutStringToMaxLength getContentOfFileAsOneString convertAloeDateToYearMonthDay replaceSpecialCharacters getContentOfFileAsOneStringWithEncodingParameter convertKeywordStringGenericToAloeStyle trim writeRawDataToTemporaryFile decodePerlJsonStringToPerlStructure isContainedInArray askForPassword stringToCamelCaseId parseStreetAndNumber);



#############################################################################
# Remove all sequences of one or more whitespace characters with exactly one blank
sub spaceCleanup {
    my( $toClean ) = @_;

    if ( defined( $toClean ) ) {
	$toClean =~ s/\s+/ /g;
    }
    return( $toClean );
}
#############################################################################
sub isContainedInArray {

    my( $oneElement, @arrayToCheck ) = @_;

    foreach my $element ( @arrayToCheck ) {
        return( 1 ) if $element eq $oneElement;
    }

    return( 0 );
}
#############################################################################
sub isHelpFlagInArray {

    foreach my $element ( @_ ) {
        return( 1 ) if $element eq '-h' or $element eq '--help';
    }

    return( 0 );
}
#############################################################################
# Returns an array reference ( $street, $number ) if parsing succeeds, (undef, undef) otherwise
sub parseStreetAndNumber {
    my( $streetAndNumber ) = @_;
    my $result = [ undef, undef ];

    if ( $streetAndNumber =~ m~^(.*?)\s([0-9-/ ]+[a-zA-Z]?)\s*$~ ) {
        my $street = trim( $1 );
        my $number = trim( $2 );
        $number =~ s/\s//g;
        $result = [ $street, $number ];
    }

    return( $result );
}

#############################################################################
# Note: Will round to 2 decimals by default. Use optional parameter $howManyDecimals to adjust
sub absoluteToRelative {
    my( $part, $total, $howManyDecimals ) = @_;
    $howManyDecimals = 2 unless defined( $howManyDecimals );
    my $result = 0;

    confess "doof\n" unless( defined($total) );
    if ( $total > 0 ) {
        $result = $part / $total;
        $result = sprintf( "%.${howManyDecimals}f", $result )
    }
    return( $result );
}

#############################################################################
# Note: maxLength must be at least 4
sub trim {
    my( $toTrim ) = @_;

    if ( defined( $toTrim ) ) {
	$toTrim =~ s/^\s*//;
	$toTrim =~ s/\s*$//;
    }
    return( $toTrim );
}
#############################################################################
# Note: maxLength must be at least 4
sub convertAloeDateToYearMonthDay {
    my( $aloeDate ) = @_;

    my $result = $aloeDate;
    $result =~ s/^[01] //;
    $result =~ s/\d{2}:\d{2}:\d{2}\s*$//;

    return( $result );
}
#############################################################################
sub convertKeywordStringToAloeStyle {
    my( $toConvert ) = @_;
    my $converted = $toConvert;
    my $bulletpoint = chr(183);

    my @chunks;
    if ( $toConvert =~ /,/ ) {
	@chunks = split( /\s*,\s*/, $toConvert );
    } elsif ( $toConvert =~ /;/ ) {
	@chunks = split( /\s*\;\s*/, $toConvert );
    } elsif ( $toConvert =~ /$bulletpoint/ ) {
	@chunks = split( /\s*$bulletpoint\s*/, $toConvert );
    } else {
	@chunks = split( /\s+/, $toConvert );
    }

    my $result = "";
    foreach my $chunk ( @chunks ) {
	next if $chunk =~ m/^\W+$/; # skip chunks containing only non-alphanumerics
	$chunk =~ s/\(|\)|\{|\}"'//g; # replace parentheses, quotes etc.
	$chunk =~ s/\W/_/g;
	if ( $chunk =~ m/\w/ ) {
	    $result .= " " unless $result eq "";
	    # Max length of a tag is 255, which is ridiculously long
	    $result .= cutStringToMaxLength( $chunk, 254 );
	}
    }
    $converted = $result;

    if ( 0 ) {
	print STDERR "##Tags: $converted\n    ";
	foreach my $x ( split( / */, $converted ) ) {
	    print STDERR ord($x), "   ";
	}
	print STDERR "\n";
    }

    return( $converted );
}
#############################################################################
# Example:
#   convertKeywordStringGenericToAloeStyle( $candidate, [ ";", "--" ], 1, qr~[^\-a-zA-Z0-9_\w\(\)\[\]/]~ );
sub convertKeywordStringGenericToAloeStyle {
    my( $toConvert, $separators, $separatorsExclusiveFlag, $regexpContainingCharactersToEliminate ) = @_;

    my $foundSomething = 0;
    my @chunks;
    foreach my $separator ( @$separators ) {
	if ( $toConvert =~ m/${separator}/ ) {
	    @chunks = split( /\s*${separator}\s*/, $toConvert );
	    $foundSomething = 1;
	    last if $separatorsExclusiveFlag;
	}
    }

    @chunks = ( $toConvert ) unless $foundSomething;

    my $result = "";
    foreach my $chunk ( @chunks ) {
	next if $chunk =~ m/^\W+$/; # skip chunks containing only non-alphanumerics

	#$chunk =~ s~[^\-a-zA-Z0-9_\w\(\)\[\]/]~_~g;
	$chunk =~ s~${regexpContainingCharactersToEliminate}~_~g;
	$chunk =~ s/_+/_/g;
	$chunk =~ s/\s+/ /g;
	$chunk =~ s/^\s*//;
	$chunk =~ s/\s*$//;
	$chunk =~ s/^_*//;
	$chunk =~ s/_*$//;
	if ( $chunk =~ m/\w/ ) {
	    if ( length( $chunk ) < 255 ) {
		$result .= " " unless $result eq "";
		# Max length of a tag is 255, which is ridiculously long
		$result .= cutStringToMaxLength( $chunk, 254 );
	    }
	}
    }

    return( $result );
}
#############################################################################
sub convertStringToFloat {
    my( $toConvert )  = @_;
    return( POSIX::strtod( $toConvert ) );
}

#############################################################################
# Convert the inputString into camel case notation (word starts lowercase, then
# all words start uppercase, rest is lowercase).
# It also replaces all german umlauts and is usually used to generate
# taxonomyIds from text input
sub stringToCamelCaseId {
    my( $inputString ) = @_;
    my @umlautReplacements = ( [ "Ä", "Ae" ], [ "Ü", "Ue" ], [ "Ö", "Oe" ], [ "ä", "ae" ], [ "ü", "ue" ], [ "ö", "oe" ], [ "ß", "ss" ] );
    foreach my $replacement ( @umlautReplacements ) {
	$inputString =~ s/$replacement->[0]/$replacement->[1]/g;
    }
    $inputString =~ s/[^A-Za-z0-9]/ /g;   #  replace non-alphanumerics with blanks
    $inputString = lc( $inputString );

    my $result = "";
    foreach my $splitted ( split( / /, $inputString ) ) {
	#my $toAdd = $result eq "" ? $splitted : ucfirst( $splitted );
	$result .= $result eq "" ? $splitted : ucfirst( $splitted );
    }
    
    return ( $result );
}
#############################################################################
# Try to get a valid ALOE date representation of the given date or time interval
# You can specify a default day (like "01" or 1) to be used in case no day is found.
# If no default day is specified and no day is found the last day of the month will
# be used
sub tryToParseSimpleStringToAloeDate {
    my( $toCheck, $defaultDay, $defaultMonth ) = @_;
    my $result = "";
    $defaultDay = "01" unless defined( $defaultDay );
    $defaultMonth = "01" unless defined( $defaultMonth );

    if ( defined( $toCheck ) ) {

	my @match = ( $toCheck =~ m~^\s*(\d{2,4})[.-](\d{1,2})(?:[-](\d{1,2}))?\s*T?(.*?)Z?\s*$~ );

	if ( @match > 0 ) {
	    #print STDERR "Found " . @match . " results\n";
	    my ( $year, $month, $day, $remaining );
	    ( $year, $month, $day, $remaining ) = @match if @match == 4;
	    ( $year, $month, $remaining ) = @match if @match == 3;
	    $month = $defaultMonth unless defined( $month );
	    $month = sprintf( "%02d", $month );
	    $year = fourDigitsYear( $year );
	    $defaultDay = lastDayOfMonth( $month, $year ) unless defined( $defaultDay );
	    $day = $defaultDay unless defined( $day );
	    $day = sprintf( "%02d", $day );

	    if ( $remaining =~ m/^(\d{2}:\d{2}:\d{2})/ ) {
		$result = "1 ${year}-${month}-${day} $1";
	    } else {
		$result = "1 ${year}-${month}-${day} 00:00:00";
	    }
	} elsif ( $toCheck =~ m~^\s*(\d{4})\s*$~ ) {
	    $result = "1 ${1}-${defaultMonth}-${defaultDay} 00:00:00";
	}
    }
    #print STDERR "$result\n" if defined( $result );
    return( $result );
}

#############################################################################
sub tryToParseOnlyYearToAloeDate {
    my( $toCheck ) = @_;
    my $result = "";

    #die "Will check: $toCheck" . "\n";

    if ( defined( $toCheck ) ) {

	my @match = ( $toCheck =~ m~^\s*(\d{4})\s*$~ );

	if ( @match > 0 ) {
	    #print STDERR "Found " . @match . " results\n";
	    my ( $year ) = @match;
	    my $month = sprintf( "%02d", 1 );
	    $year = fourDigitsYear( $year );
	    my $day = sprintf( "%02d", 1 );
	    $result = "1 ${year}-${month}-${day} 00:00:00";
	}
    }
    #print STDERR "$result\n" if defined( $result );
    return( $result );
}

#############################################################################
# Try to get a valid ALOE date representation of the given date specified in reverse
# order like 20140112.
# You can specify a default day (like "01" or 1) to be used in case no day is found.
# If no default day is specified and no day is found the last day of the month will
# be used
sub tryToParseReversedDateStringToAloeDate {
    my( $toCheck, $defaultDay ) = @_;
    my $result = "";

    #die "Will check: $toCheck" . "\n";

    if ( defined( $toCheck ) ) {

	my @match = ( $toCheck =~ m~^\s*(\d{4})(\d{2})(\d{2})\s*$~ );

	if ( @match > 0 ) {
	    #print STDERR "Found " . @match . " results\n";
	    my ( $year, $month, $day ) = @match;
	    $month = sprintf( "%02d", $month );
	    $year = fourDigitsYear( $year );
	    $defaultDay = lastDayOfMonth( $month, $year ) unless defined( $defaultDay );
	    $day = $defaultDay unless defined( $day );
	    $day = sprintf( "%02d", $day );
	    $result = "1 ${year}-${month}-${day} 00:00:00";
	}
    }
    #print STDERR "$result\n" if defined( $result );
    return( $result );
}
#############################################################################
# Try to get a valid ALOE date representation of the given date or time interval
# You can specify a default day (like "01" or 1) to be used in case no day is found.
# If no default day is specified and no day is found the last day of the month will
# be used
sub tryToParseStringToAloeDate {
    my( $toCheck, $defaultDay ) = @_;
    my $result = "";

    if ( defined( $toCheck ) ) {

	my @match = ( $toCheck =~ m~^\s*(?:(\d{1,2})[./])?\s*(\d{1,2})[./]\s*(\d{2,4})\s*$~ );

	if ( @match > 0 ) {
	    #print STDERR "Found " . @match . " results\n";
	    my ( $day, $month, $year ) = @match;
	    $month = sprintf( "%02d", $month );
	    $year = fourDigitsYear( $year );
	    $defaultDay = lastDayOfMonth( $month, $year ) unless defined( $defaultDay );
	    $day = $defaultDay unless defined( $day );
	    $day = sprintf( "%02d", $day );
	    $result = "1 ${year}-${month}-${day} 00:00:00";
	}
    }
    #print STDERR "$result\n" if defined( $result );
    return( $result );
}
#############################################################################
# Try to get a valid ALOE date representation of the given date or time interval
# You can specify a default day (like "01" or 1) to be used in case no day is found.
# If no default day is specified and no day is found the last day of the month will
# be used
sub tryToParseStringToAloeDateAndTime {
    my( $toCheck, $defaultDay ) = @_;
    my $result = "";

    if ( defined( $toCheck ) ) {

	my @match = ( $toCheck =~ m~^\s*(\d{1,2})[./]\s*(\d{1,2})[./]\s*(\d{2,4}),?\s+(\d{2})[:.](\d{2})(?:[:.](\d{2})?)?\s*$~ );

	if ( @match > 0 ) {
	    #print STDERR "Found " . @match . " results\n";
	    my ( $day, $month, $year, $hours, $minutes, $seconds ) = @match;
	    $month = sprintf( "%02d", $month );
	    $year = fourDigitsYear( $year );
	    $defaultDay = lastDayOfMonth( $month, $year ) unless defined( $defaultDay );
	    $day = $defaultDay unless defined( $day );
	    $day = sprintf( "%02d", $day );
	    $seconds = "00" unless defined( $seconds );
	    $result = "1 ${year}-${month}-${day} ${hours}:${minutes}:${seconds}";
	}
    }
    #print STDERR "$result\n" if defined( $result );
    return( $result );
}

#############################################################################
sub isEmpty {
    return( ! isNotEmpty( @_ ) );
}
#############################################################################
sub isNotEmpty {
    my( $toCheck ) = @_;
    return( defined( $toCheck ) and $toCheck ne "" );
}
#############################################################################
sub lastDayOfMonth {
    my( $month, $year ) = @_;
    my $result = undef;

    if ( $month =~ m/^(01|03|05|07|08|10|12)$/ ) {
	$result = "31";
    } elsif ( $month =~ m/^(04|06|09|11)$/ ) {
	$result = "30";
    } else {
	$result = "28";

	if ( $year % 4 == 0 and ( $year % 100 != 0 or $year % 400 == 0 ) ) {
	    $result = "29";
	}
    }

    return( $result );
}
#############################################################################
sub fourDigitsYear {
    my( $year ) = @_;

    if ( $year < 100 ) {
	if ( $year > 70 ) {
	    $year = "19" . $year;
	} else {
	    $year = "20" . $year;
	}
    }
    return( $year );
}

#############################################################################
# Note: maxLength must be at least 4
sub cutStringToMaxLength {
    my( $toCut, $maxLength ) = @_;
    my $cutString = $toCut;

    if ( defined( $toCut ) and $maxLength > 3 and length( $toCut ) > $maxLength ) {
	$cutString = substr( $toCut, 0, $maxLength - 3 ) . "...";
    }
    return( $cutString );
}
#############################################################################

sub getContentOfFileAsOneString {
    my( $filename ) = @_;

    open my $fileHandle, "<:encoding(utf8)", "$filename" or die "Error while reading $filename: $!";
    local $/;			# enable "slurp" mode
    my $content = <$fileHandle>;
    close( $fileHandle );
    return( $content );
}

#############################################################################
# Encoding should be something like iso-8859-1 or cp-1252 or the like
sub getContentOfFileAsOneStringWithEncodingParameter {
    my( $filename, $encoding ) = @_;

    open my $fileHandle, "<:encoding($encoding)", "$filename" or die "Error while reading $filename: $!";
    #open my $fileHandle, "<:encoding(cp-1258)", "$filename" or die "Error while reading $filename: $!";
    local $/;			# enable "slurp" mode
    my $content = <$fileHandle>;
    close( $fileHandle );
    return( $content );
}

#############################################################################

sub replaceSpecialCharactersInJson {
    my( $inputString ) = @_;
    my $elimination = "(\x00|\x01|\x02|\x03|\x04|\x05|\x06|\x07|\x08|\x10|\x11|\x12|\x13|\x14|\x15|\x16|\x17|\x18|\x1e|\x1f|\xfffe|\xffff)";

    my %toReplace = ( "\x{100000}" => "-" );
    #		    "\x0b" => "ff", "\x0c" => "fi", "\x0e" => "ffi", "\x19" => "ss", "\x1b" => "ff", "\x1c" => "fi", "\x1d" => "fl",
    #		    "\x{100000}" => "-" );

    $inputString=~ s/$elimination//g;
    foreach my $characterToReplace ( keys %toReplace ) {
	my $replacement = $toReplace{$characterToReplace};
	$inputString=~ s/$characterToReplace/$replacement/g;
    }
    return( NFD( $inputString ) );
}

#############################################################################

sub replaceSpecialCharacters {
    my( $inputString ) = @_;
    my $elimination = "(\x00|\x01|\x02|\x03|\x04|\x05|\x06|\x07|\x08|\x10|\x11|\x12|\x13|\x14|\x15|\x16|\x17|\x18|\x1e|\x1f|\xfffe|\xffff)";

    my %toReplace = ( "\x0b" => "ff", "\x0c" => "fi", "\x0e" => "ffi", "\x19" => "ss", "\x1b" => "ff", "\x1c" => "fi", "\x1d" => "fl",
		      "\x00\xa4" => "",
		      "\xf4\x80\x80\x80" => "-" );

    $inputString=~ s/$elimination//g;
    foreach my $characterToReplace ( keys %toReplace ) {
	my $replacement = $toReplace{$characterToReplace};
	$inputString=~ s/$characterToReplace/$replacement/g;
    }
    return( $inputString );
}

#############################################################################

sub arrayReferenceOrStringToString {
    my( $input, $separator, $hook ) = @_;
    my $result = $input;
    if ( ref( $input ) eq "ARRAY" ) {
	my @cleanedUpArray;
	foreach my $rawElement ( @$input ) {
	    #push( @cleanedUpArray, $rawElement ) if $rawElement =~ m/[\x21-\x7E]/;
	    if ( defined( $hook ) ) {
		my $processedElement = $hook->( $rawElement );
		push( @cleanedUpArray, $processedElement ) if isNotEmpty( $processedElement );
	    } else {
		push( @cleanedUpArray, $rawElement );
	    }
	}
	$result = join( $separator, @cleanedUpArray );
    }
    return( $result );
}

#############################################################################

sub hashReferenceToString {
    my( $hashReference ) = @_;
    my $result = "";
    if ( ref( $hashReference ) eq "HASH" ) {
	foreach my $key ( sort keys %$hashReference ) {
	    my $value = $hashReference->{$key};
	    if ( ref( $value ) eq "ARRAY" ) {
		$result .= "'${key}': '" . arrayReferenceOrStringToString( $value, ", " ) . "'\n";
	    } else {
		$result .= "'${key}': '${value}'\n";
	    }
	}
    }
    return( $result );
}
#############################################################################

# Compare two numerical version strings.
# Will return  1      if first string is greater than second
#             -1      if second string is greater than first
#              0      if version strings are equal
#              undef  if at least one of the version strings is empty or
#                     contains non-number-characters
#
# Sample call:
#   compareNumericalVersions( "1.2.3", "2.0.0" )
#
sub compareNumericalVersions {
    my( $version1, $version2 ) = @_;
    my @version1Parts = split( /\./, $version1 );
    my @version2Parts = split( /\./, $version2 );

    my $resultOfComparison = 0;

    foreach my $x ( ( @version1Parts, @version2Parts ) ) {
        if ( $x !~ m/^\d+$/ ) {
            warn "Part of version string '$x' is not a number\n";
            $resultOfComparison = undef;
        }
    }

    if ( defined( $resultOfComparison ) and @version1Parts > 0 and @version2Parts > 0 ) {
        while( $resultOfComparison == 0 and @version1Parts > 0 and @version2Parts > 0 ) {
            my $one = shift( @version1Parts );
            my $two = shift( @version2Parts );
            $resultOfComparison = $one <=> $two;
        }

        if ( defined( $resultOfComparison ) and $resultOfComparison == 0 ) {
            if ( @version1Parts > 0 ) {
                $resultOfComparison = 1;
            }
            elsif ( @version2Parts > 0 ) {
                $resultOfComparison = -1;
            }
        }
    }

    return( $resultOfComparison );
}
#############################################################################

sub decodePerlJsonStringToPerlStructure {
    my( $toDecode ) = @_;
    my $jsonBytes = encode( "UTF-8", $toDecode );
    my $perlStructure = decode_json( $jsonBytes );

    return( $perlStructure );
}
#############################################################################
sub writeRawDataToTemporaryFile {
    my( $rawData, $prefix, $extension ) = @_;

    my $fileHandle = _getTemporaryFilehandle( $prefix, $extension );

    my $written = syswrite( $fileHandle, $rawData );
    if ( ! defined( $written ) ) {
	confess( "Could not write raw data to file: $!\n" );
    }

    my $fileName = $fileHandle->filename;
    $fileHandle->close();

    return( $fileName );
}
#############################################################################
# Arguments (except the instance reference $self) are expected to be provided
# as hash. Possible keys:
#    SUFFIX
#    DIR
#    UNLINK   (* default 1 *)
#    TEMPLATE
sub _getTemporaryFilehandle {
    my ( $prefix, $extension ) = @_;

    my %options;
    $options{DIR} = "/tmp";
    $options{UNLINK} = 0;
    $options{SUFFIX} = $extension;
    $options{TEMPLATE} = "${prefix}_output_XXXXXXXX" unless exists( $options{TEMPLATE} );

    my $fileHandle = File::Temp->new( %options );
    return( $fileHandle );
}

#############################################################################
sub iso8601DateStringToSecondsSinceEpoch {
    my( $dateString ) = @_;
    my $format = DateTime::Format::Strptime->new( pattern => "%FT%T%z");
    $dateString =~ s/^(.{19})\.\d{3}/$1/;

    my $dt = $format->parse_datetime( $dateString );

    my $result = undef;
    if ( $dt ) {
        $result = DateTime::Format::Strptime::strftime( "%s", $dt );
    }
    else {
        warn "Found illegal date string: $dateString\n";
    }

    return( $result );
}
#############################################################################
# Returns the number of seconds since epoch for string input of the
# form dd.mm.yyyy HH:MM:SS representing a local time specification (MET/MEST)

sub localDateToSecondsSinceEpoch {
    my( $dateString ) = @_;

    if ( $dateString =~ m/(\d{2})\.(\d{2})\.(\d{4}) (\d{2})\:(\d{2})\:(\d{2})/ ) {
        # hk: grrr. I always fall for this fucking idea to number months from 0 to 11
        ##  timelocal( $sec, $min, $hour, $mday, $mon, $year );
        my $time = timelocal( $6, $5, $4, $1, $2 - 1, $3 );
        #print STDOUT "Translated timestamp $dateString to localtime $time\n";
        return( $time );
    }
    else {
        warn "Found illegal date string: $dateString\n";
        return( undef );
    }
}

#############################################################################
# Check the command line parameters for all given parameter managers.
# Will return a pair of values ( $wasSuccessful, $errorString ).
#
# If any of the managers fails to validate the parameters, $wasSuccessful
# is 0 and $errorString will show the allowed parameters and maybe give
# a hint what went wrong
# Otherwise $wasSuccessful is 1 and $errorString an empty string.
sub checkCommandlineAndInitSeveralParameterManagers {
    my( $argvReference, $dieIfNotOkay, $usageStringProvidedByUser, @allParameterManagers ) = @_;
    my $allManagersSuccessful = 1;
    my $outputString = "";

    foreach my $parameterManager ( @allParameterManagers ) {
	my( $returnValue ) = $parameterManager->initFromCommandlineParameters( $argvReference );
	if ( $returnValue != 1 ) {
	    $allManagersSuccessful = 0;
	}
	$outputString .= $parameterManager->getUsageString();
	$outputString .= "\n";
    }
    
    if ( defined( $usageStringProvidedByUser ) ) {
	$outputString .= "\n$usageStringProvidedByUser\n";
    }

    if ( $allManagersSuccessful != 1 ) {
	if ( $dieIfNotOkay ) {
	    die $outputString;
	}
    }
    return( $allManagersSuccessful, $outputString );
}
#############################################################################
sub askForPassword {
    my ( $user ) = @_;

    print STDERR "Please type the password for user ${user}: ";
    ReadMode('noecho');
    my $password = ReadLine( 0 );
    chomp $password;
    ReadMode('restore');
    print STDERR "\n";
    return( $password );
}
#############################################################################

1;
