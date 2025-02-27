=pod

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME
	
	Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf;

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf

    To run on a collection:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -collection <species_set_name>
        or
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -species_set_id <species_set dbID>

    To run on a pair of species:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -species1 homo_sapiens -species2 gallus_gallus

=head1 DESCRIPTION

    This pipeline uses whole genome alignments to calculate the coverage of homologous pairs.
    The coverage is calculated on both exonic and intronic regions seperately and summarised using a quality_score calculation
    The average quality_score between both members of the homology will be written to the homology table (in compara_db option)

    http://www.ebi.ac.uk/seqdb/confluence/display/EnsCom/Quality+metrics+for+the+orthologs

    Additional options:
    -compara_db         database containing relevant data (this is where final scores will be written)
    -alt_aln_db         take alignment objects from a different source
    -alt_homology_db    take homology objects from a different source

    Note: If you wish to use homologies from one database, but the alignments live in a different database,
    remember that final scores will be written to the homology table of the appointed compara_db. So, if you'd 
    like the final scores written to the homology database, assign this as compara_db and use the alt_aln_db option 
    to specify the location of the alignments. Likewise, if you want the scores written to the alignment-containing
    database, assign it as compara_db and use the alt_homology_db option.

    Examples:
    ---------
    # scores go to homology db, alignments come from afar
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -compara_db mysql://user:pass@host/homologies
        -alt_aln_db mysql://ro_user@hosty_mchostface/alignments

    # scores go to alignment db
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf -compara_db mysql://user:pass@host/alignments
        -alt_homology_db mysql://ro_user@hostess_with_the_mostest/homologies

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::OrthologQM_Alignment_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ( 'Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf' );

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class

        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones
        'compara_db'      => "mysql://ensadmin:$ENV{EHIVE_PASS}\@compara5/cc21_ensembl_compara_84",
        'species1'        => undef,
        'species2'        => undef,
        'collection'      => undef,
        'species_set_id'  => undef,
        'ref_species'     => undef,
        'reg_conf'        => "$ENV{'ENSEMBL_CVS_ROOT_DIR'}/ensembl-compara/scripts/pipeline/production_reg_conf.pl",
        'alt_aln_db'      => undef,
        'alt_homology_db' => undef,
        'previous_rel_db' => undef,
        'user'            => 'ensadmin',
        'orth_batch_size' => 10, # set how many orthologs should be flowed at a time     
    };
}

=head2 pipeline_create_commands 
	
	Description: create tables for writing data to

=cut

sub pipeline_create_commands {
	my $self = shift;

	return [
		@{ $self->SUPER::pipeline_create_commands },
		$self->db_cmd( 'CREATE TABLE ortholog_quality (
			homology_id              INT NOT NULL,
            genome_db_id             INT NOT NULL,
            alignment_mlss           INT NOT NULL,
            combined_exon_coverage   FLOAT(5,2) NOT NULL,
            combined_intron_coverage FLOAT(5,2) NOT NULL,
			quality_score            FLOAT(5,2) NOT NULL,
            exon_length              INT NOT NULL,
            intron_length            INT NOT NULL,
            INDEX (homology_id)
        )'),
        $self->db_cmd( 'CREATE TABLE exon_boundaries (
            gene_member_id   INT NOT NULL,
            dnafrag_start    INT NOT NULL,
            dnafrag_end      INT NOT NULL,
            seq_member_id    INT NOT NULL,
            INDEX (gene_member_id)  
        ) ENGINE=InnoDB' ),
	];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'take_time'       => 1,
        'orth_batch_size' => 100,
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
        'default'                => {'LSF' => '-C0 -M100   -R"select[mem>100]   rusage[mem=100]"' },
        '200M_job'               => {'LSF' => '-C0 -M200   -R"select[mem>200]   rusage[mem=200]"' },
        '2Gb_job'                => {'LSF' => '-C0 -M2000  -R"select[mem>2000]  rusage[mem=2000]"' },
        '4Gb_job_with_reg_conf'  => {'LSF' => ['-C0 -M4000  -R"select[mem>4000]  rusage[mem=4000]"', '--reg_conf '.$self->o('reg_conf')] },
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'pair_species',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PairCollection',
            -flow_into  => {
                '2->A' => [ 'prepare_exons' ],
                'A->1' => [ 'exon_funnel' ],
                '3'    => [ 'reset_mlss' ],
            },
            -input_ids => [{
                'collection'      => $self->o('collection'),
                'species_set_id'  => $self->o('species_set_id'),
                'ref_species'     => $self->o('ref_species'),
                'compara_db'      => $self->o('compara_db'),
                'species1'        => $self->o('species1'),
                'species2'        => $self->o('species2'),
                'compara_db'      => $self->o('compara_db'),
                'alt_aln_db'      => $self->o('alt_aln_db'),
                'alt_homology_db' => $self->o('alt_homology_db'),
                'previous_rel_db' => $self->o('previous_rel_db'),
            }],
        },

        {   -logic_name => 'exon_funnel',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::ExonFunnel',
            -flow_into  => {
                1 => [ 'select_mlss' ],
            }
        },

        {   -logic_name        => 'prepare_exons',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareExons',
            -analysis_capacity => 50,
            -batch_size        => 10,
            -flow_into         => {
                1 => [ '?table_name=exon_boundaries' ] 
            },
            -rc_name => '4Gb_job_with_reg_conf',
            -analysis_capacity => 50,
            #-input_ids => {}
        },

        {   -logic_name => 'reset_mlss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::ResetMLSS',
        },

        {   -logic_name => 'select_mlss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SelectMLSS',
            -flow_into  => {
                1 => [ 'write_threshold' ],
                2 => [ 'prepare_orthologs' ],
            },
            -rc_name => '200M_job',
        },

        {   -logic_name => 'prepare_orthologs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs',
            -analysis_capacity  =>  100,  # use per-analysis limiter
            -flow_into => {
                2 => [ 'calculate_wga_coverage' ],
            },
            -rc_name => '2Gb_job',
        },

        {   -logic_name => 'calculate_wga_coverage',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CalculateWGACoverage',
            -analysis_capacity => 200,
            -batch_size => 5,
            -flow_into  => {
                '1'  => [ '?table_name=ortholog_quality' ],
                '2'  => [ 'assign_wga_coverage_score' ],
                '-1' => [ 'calculate_wga_coverage_himem' ],
            },
            -rc_name => '2Gb_job',
        },

        {   -logic_name => 'calculate_wga_coverage_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CalculateWGACoverage',
            -flow_into  => {
                1 => [ '?table_name=ortholog_quality' ],
                2 => [ 'assign_wga_coverage_score' ],
            },
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'assign_wga_coverage_score',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore',
            -analysis_capacity => 50,
            -batch_size        => 10,
        },

        {   -logic_name => 'write_threshold',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::WriteThreshold'

        },

    ];
}

1;