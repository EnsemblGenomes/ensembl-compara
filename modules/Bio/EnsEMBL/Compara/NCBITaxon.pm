=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::NCBITaxon

=head1 DESCRIPTION

Attributes:
  - taxon_id()
  - rank()

Names:
  - scientific_name()
  - common_name()
  - ensembl_alias_name()
  - short_name()
  - get_short_name()

Only for species level and below
  - genus()
  - species()
  - subspecies()

Others:
  - toString()
  - classification()

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::NCBITaxon;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

our @ISA = qw(Bio::EnsEMBL::Compara::NestedSet);

=head2 copy

  Description: returns copy of object, calling superclass copy method

=cut

sub copy {
  my $self = shift;
  
  my $mycopy = $self->SUPER::copy;
  
  $mycopy->ncbi_taxid($self->ncbi_taxid);
  $mycopy->rank($self->rank);
  $mycopy->genbank_hidden_flag($self->genbank_hidden_flag);

  return $mycopy;
}


## ncbi_taxid is an alias for dbID
sub ncbi_taxid {
    my $next = $_[0]->can('dbID');
    goto($next);
}

## taxon_id is an alias for dbID
sub taxon_id {
    my $next = $_[0]->can('dbID');
    goto($next);
}

sub dbID {
  my $self = shift;
  my $value = shift;
  $self->node_id($value) if($value); 
  return $self->node_id;
}

sub rank {
  my $self = shift;
  $self->{'_rank'} = shift if(@_);
  return $self->{'_rank'};
}

sub genbank_hidden_flag {
  my $self = shift;
  $self->{'_genbank_hidden_flag'} = shift if(@_);
  return $self->{'_genbank_hidden_flag'};
}

=head2 classification

  Arg[SEPARATOR]  : String (optional); used to separate the classification by
                    when returning as a string. If not specified then a single
                    space will be used.
  Arg[FULL]       : Boolean (optional); indicates we want all nodes including
                    those which Genbank sets as hidden
  Arg[AS_ARRAY]   : Boolean (optional); says the return type will be an 
                    ArrayRef of all nodes in the classification as instances
                    of NCBITaxon.
  Example         : my $classification_string = $node->classification();
  Description     : Returns the String representation of a taxon node's 
                    classification or the objects which constitute it (
                    including the current node). The String return when
                    split is compatible with BioPerl's Species classification
                    code and will return a data structure compatible with
                    that found in core species MetaContainers.
                    
                    This code is a redevelopment of existing code which
                    descended down the taxonomy which had disadvanatages 
                    when a classification was requested on nodes causing
                    the taxonomy to bi/multi-furcate.
                    
                    Note the String representation does have some disadvantages
                    when working with the poorer end of the taxonomy where
                    species nodes are not well defined. For these situations
                    you are better using the array representation and 
                    capturing the required information from the nodes.
                    
                    Also to maintain the original functionality of the method
                    we filter any species, subspecies or subgenus nodes above
                    the current node. For the true classification always
                    call using the array structure.
                    
                    Recalling this subroutine with the same parameters for
                    separators will return a cached representation. Calling
                    for AS_ARRAY will cause the classificaiton to be 
                    recalculated each time.
  Returntype      : String if not asking for an array otherwise the array
  Exceptions      : - 
  Caller          : Public

=cut
 
sub classification {
  my ($self, @args) = @_;
  my ($separator, $full, $as_array) = rearrange([qw( SEPARATOR FULL AS_ARRAY )], @args);

  #setup defaults
  $separator = ' ' unless(defined $separator);
  $full = 0 unless (defined $full);
  
  if(!$as_array) {
    #Reset the separators & classifications if we already had one & it 
    #differed from the input
    if(defined $self->{_separator} && $self->{_separator} ne $separator) {
      $self->{_separator} = undef;
      $self->{_classification} = undef;
    }
    if(defined $self->{_separator_full} && $self->{_separator_full} ne $separator) {
      $self->{_separator_full} = undef;
      $self->{_classification_full} = undef;
    }
    
    $self->{_separator} = $separator unless (defined $self->{_separator});
    $self->{_separator_full} = $separator unless (defined $self->{_separator_full});
    
    return $self->{_classification_full} if ($full && defined $self->{_classification_full});
    return $self->{_classification} if (!$full && defined $self->{_classification});
  }  

  my $node = $self;
  my @classification;
  while( $node->name() ne 'root' ) {
    my $subgenus = $node->rank() eq 'subgenus';
    if($full) {
      push(@classification, $node);
    }
    else {
      unless($node->genbank_hidden_flag() || $subgenus) {
        push(@classification, $node);
      }
    }
    
    $node = $node->parent();
  }
  
  if($as_array) {
    return \@classification;
  }

  #Once we have a normal array we can do top-down as before to replicate 
  #the original functionality
  my $text_classification = $self->_to_text_classification(\@classification);
  
  if ($full) {
    $self->{_classification_full} = join($separator, @{$text_classification});
    $self->{_separator_full} = $separator;
    return $self->{_classification_full};
  } else {
    $self->{_classification} = join($separator, @{$text_classification});
    $self->{_separator} = $separator;
    return $self->{_classification};
  }
}

=head2 _to_text_classification

  Arg[1]          : ArrayRef of the classification array to be converted to 
                    the text classification 
  Example         : my $array = $node->_to_text_classification(\@classification);
  Description     : Returns the Array representation of a taxon node's 
                    classification or the objects which constitute it (
                    including the current node) as the species names or split
                    according to the rules for working with BioPerl.
  Returntype      : ArrayRef of Strings
  Exceptions      : - 
  Caller          : Private

=cut

sub _to_text_classification {
  my ($self, $classification) = @_;
  my @text_classification;
  my $first = 1;
  for my $node ( @{$classification}) {
    my $subgenus = $node->rank() eq 'subgenus';
    my $species = $node->rank() eq 'species';
    my $subspecies = $node->rank() eq 'subspecies';
    
    if($first) {
      if($species || $subspecies) {
        my ($genus, $species, $subspecies) = split(q{ }, $node->binomial());
        unshift @text_classification, $species;
        unshift @text_classification, $subspecies if (defined $subspecies);
      }
      $first = 0;
      next;
    }
    
    next if $subgenus || $species || $subspecies;
    push(@text_classification, $node->name());
  }
  return \@text_classification;
}

=head2 subspecies

  Example    : $ncbi->subspecies;
  Description: Returns the subspeceis name for this species
  Example    : "verus" for Pan troglodytes verus
  Returntype : string
  Exceptions :
  Caller     : general

=cut

sub subspecies {
  my $self = shift;

  $self->_split_name_into_parts unless (defined $self->{'_subspecies'});

  return $self->{'_species'};
}


=head2 species

  Example    : $ncbi->species;
  Description: Returns the speceis name for this species
  Example    : "sapiens" for Homo sapiens
  Returntype : string
  Exceptions :
  Caller     : general

=cut

sub species {
  my $self = shift;

  $self->_split_name_into_parts unless (defined $self->{'_species'});

  return $self->{'_species'};
}


=head2 genus

  Example    : $ncbi->genus;
  Description: Returns the genus name for this species
  Returntype : string
  Example    : "Homo" for Homo sapiens
  Exceptions :
  Caller     : general

=cut

sub genus {
  my $self = shift;

  $self->_split_name_into_parts unless (defined $self->{'_genus'});

  return $self->{'_genus'};
}


sub _split_name_into_parts {
    my $self = shift;
    if ($self->rank eq 'species' || $self->rank eq 'subspecies') {
        my ($genus, $species, @subspecies) = split(' ', $self->scientific_name);
        $self->{'_species'} = $species;
        $self->{'_genus'} = $genus;
        $self->{'_subspecies'} = join(' ', @subspecies);
    } else {
        $self->{'_species'} = '';
        $self->{'_genus'} = '';
        $self->{'_subspecies'} = '';
    }
}


=head2 common_name

  Example    : $ncbi->common_name;
  Description: Getter/setter for the comon name as defined by Genbank
  Returntype : string
  Exceptions : returns undef if no genbank common name exists.
  Caller     : general

=cut

sub common_name {
    my $self = shift;
    return $self->_getter_setter_for_tag('genbank common name', @_);
}

=head2 ensembl_alias_name

  Example    : $ncbi->ensembl_alias_name;
  Description: Getter/setter for the comon name as defined by ensembl alias
  Returntype : string
  Exceptions : returns undef if no ensembl alias name exists.
  Caller     : general

=cut

sub ensembl_alias_name {
    my $self = shift;
    return $self->_getter_setter_for_tag('ensembl alias name', @_);
}


=head2 scientific_name

  Example    : $ncbi->scientific_name;
  Description: Getter/setter for the scientific name of this taxon
  Returntype : string
  Exceptions :
  Caller     : general

=cut

sub scientific_name {
    my $self = shift;
    return $self->_getter_setter_for_tag('scientific name', @_);
}

sub name {
    my $self = shift;
    return $self->scientific_name(@_);
}


sub binomial {  ## DEPRECATED
  my $self = shift;
  deprecate('NCBITaxon::binomial() is deprecated will be removed in e88. Use scientific_name) instead (and filter by rank="species" or "subspecies" if needed)');
  if ($self->rank eq 'species' || $self->rank eq 'subspecies') {
      return $self->scientific_name;
  } else {
    warning("taxon_id=",$self->node_id," is not a species or subspecies. So binomial is undef (try the scientific_name method)\n");
    return undef;
  }
}

=head2 get_short_name

  Example    : $ncbi->get_short_name;
  Description: The name of this genome in the Gspe ('G'enera
               'spe'cies) format. Further names are just added
               at the end (Gen Spec Subname -> GSpeSubname)
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub get_short_name {
  my $self = shift;
  my $name = $self->name;
  $name =~  s/(\S)\S+\s(\S{3})\S+/$1$2/;
  $name =~ s/\ //g;
  return $name;
}


=head2 toString

  Example    : print $taxon->toString();
  Description: used for debugging, returns a string with the key descriptive
               elements of this taxon
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub toString {
    my $self = shift;
    my $type = ref($self);
    $type =~ s/^.*:://;
    my $str = sprintf('NCBITaxon taxon_id=%s %s (%s)', $self->dbID || '?', $self->name, $self->rank);
    return $str;
}


sub print_node {
  my $self  = shift;
  printf("(%s", $self->node_id);
  printf(" %s", $self->rank) if($self->rank);
  print(")");
  printf("%s", $self->name) if($self->name);
  print("\n");
}

1;
