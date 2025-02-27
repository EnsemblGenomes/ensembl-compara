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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::LoadAllMasterGenomeDB_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::LoadAllMasterGenomeDB_conf -password <your_password>

=head1 DESCRIPTION  

This is a test of JobFactory + LoadOneGenomeDB Runnables

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::LoadAllMasterGenomeDB_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'reg1' => {
            -host   => 'ens-staging',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'reg2' => {
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        master_db => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'mm14_ensembl_compara_master',
        }
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'db_conn'           => $self->o('master_db'),
                'all_current'       => 1,
            },
            -input_ids  => [
                { },    # the input_id template is now fully defined by the query's column_names (hence the need to rename them).
                        # If you want to load the latest assembly for the genome, skip 'assembly assembly_name' field from the query.
            ],
            -flow_into => {
                2 => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#' }, },
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_dbs'  => [ $self->o('reg1'), $self->o('reg2'), ],
            },
            -flow_into => {
                1 => [ 'dummy' ],   # each will flow into another one
            },
        },

        {   -logic_name    => 'dummy',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -hive_capacity => 10,       # allow several workers to perform identical tasks in parallel
        },
    ];
}

1;

