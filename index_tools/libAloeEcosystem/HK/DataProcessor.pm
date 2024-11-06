package HK::DataProcessor;

use strict;
use warnings;

# To export only selected functions (or variables), we derive
# from class 'Exporter', so the user can call method 'import()'
# of class 'Exporter'
use Exporter;
our @ISA = ( 'Exporter' );
# which functions to export by default?
our @EXPORT = qw();
# which functions to export byuser request?
our @EXPORT_OK = qw();


#############################################################################################

# Constructor of class HK::DataProcessor
# You can specify an additional hash with configuration parameters. Accepted keys:
#   mandatoryFields   a hash reference where the keys are the names of the fields expected as mandatory in checked data.
#                     If you want to use method createOutputFromInput the values should represent the name of the
#                     keys to be used for the fields in the translated output
#                     All contained keys will be regarded mandatory.
#   optionalFields    a hash reference where the keys are the names of the fields expected as mandatory in checked data.
#                     If you want to use method createOutputFromInput the values should represent the name of the
#                     keys to be used for the fields in the translated output
#                     All contained keys will be regarded optional.
sub new {
    my $class = shift;
    my $self  = {};

    bless ($self, $class);

    $self->_init( @_ );

    return $self;
}
#############################################################################################
# You can specify additional hashes for configuration via keys 'mandatoryFields' and 'optionalFields'
sub _init {
    my $self = shift;

    my %additionalParameters = @_;
    $self->{mandatoryFields} = {};
    $self->{optionalFields} = {};
    $self->{fieldsToIgnore} = {};
    $self->{_checked} = 0;
    $self->{_currentFileName} = undef;
    $self->{dieOnError} = 0;

    while ( my( $key, $value ) = each %additionalParameters ) {
        # keys starting with _ may not be overwritten
        $self->{$key} = $additionalParameters{$key} unless $key =~ m/^_/;
    }
}
#############################################################################################
sub createOutputFromInput {
    my( $self, $inputElement ) = @_;
    my $output = {};

    foreach my $key ( keys %{ $self->{mandatoryFields} } ) {
        my $value = $self->{mandatoryFields}->{$key};
        $output->{$value} = $inputElement->{$key};
    }
    foreach my $key ( keys %{ $self->{optionalFields} } ) {
        if ( exists( $inputElement->{$key} ) ) {
            my $value = $self->{optionalFields}->{$key};
            $output->{$value} = $inputElement->{$key};
        }
    }

    return( $output );
}
#############################################################################################
sub resetCheckedState {
    my( $self, $fileName ) = @_;
    $self->{_currentFileName} = $fileName;
    $self->{_checked} = 0;
}

#############################################################################################
# Check if the given parameter (expected to represent a hash reference) is containing all mandatory
# fields and there are no non-mandatory fields present not specified as optional
sub checkInput {
    my( $self, $inputElement ) = @_;
    return( $self->_checkInput( $inputElement, 0 ) );
}
#############################################################################################
# Check if the given parameter (expected to represent a hash reference) is containing all mandatory
# fields and there are no non-mandatory fields present not specified as optional
# If the check was already performed, no further check will take place
sub checkInputIfNotAlreadyCheckedAndOkay {
    my( $self, $inputElement ) = @_;
    return( $self->_checkInput( $inputElement, $self->{_checked} ) );
}
#############################################################################################
# Check if the given hash is containing all mandatory fields and there are no unexpected
# fields in the input structure
sub _checkInput {
    my( $self, $inputElement, $isAlreadyChecked ) = @_;
    my $checkIsOkay = 0;
    
    if ( ! $isAlreadyChecked ) {
        my @tooMuch = ();

        # create shallow copy of $self->{mandatoryFields}
        my %expectedFields = %{ $self->{mandatoryFields} };
        
        foreach my $field ( keys %$inputElement ) {
            if ( ! exists( $expectedFields{$field} ) ) {
                if ( not exists( $self->{optionalFields}->{$field} ) and not exists( $self->{fieldsToIgnore}->{$field} ) ) {
                    push( @tooMuch, $field );
                }
            }
            else {
                delete( $expectedFields{$field} );
            }
        }
            
        my @missing = keys %expectedFields;
        
        if ( @missing == 0 and @tooMuch == 0 ) {
            $self->{_checked} = 1;
            $checkIsOkay = 1;
        }
        else {
            my $warningText = "";
            if ( defined( $self->{_currentFileName} ) ) {
                $warningText = "Inconsistency detected when processing file " . $self->{_currentFileName} . "\n";
            }
            if ( @missing > 0 ) {
                $warningText .= "The following fields were missing:\n";
                foreach my $x ( sort @missing ) {
                    $warningText .= "  $x\n";
                }
            }
            if ( @tooMuch > 0 ) {
                $warningText .= "The following fields were unexpected:\n";
                foreach my $x ( sort @tooMuch ) {
                    $warningText .= "  $x\n";
                }
            }
            if ( $self->{dieOnError} ) {
                die $warningText;
            }
            else {
                warn $warningText;
            }
        }
    }
    else {
        $checkIsOkay = 1;
    }

    return( $checkIsOkay );
}


1;
