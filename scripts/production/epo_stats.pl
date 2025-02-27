#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;
use DBI;

# use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;

my ( $help, $url, $mlss_id, $html );
GetOptions(
    "help"      => \$help,
    "url=s"     => \$url,
    "mlss_id=i" => \$mlss_id,
    "html"      => \$html,
);

if ( $help || !$url ){
	die "Usage: epo_stats.pl -url <url_to_epo_db> [-mlss_id <ID> (optional)]\n\n";
}

my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $url );

my $gdb_a = $dba->get_GenomeDBAdaptor;
my $gdbs  = $gdb_a->fetch_all();

my $mlss_a = $dba->get_MethodLinkSpeciesSetAdaptor;
my $mlss;
if ( defined $mlss_id ) {
	$mlss = [ $mlss_a->fetch_by_dbID($mlss_id) ];
	die "Cannot find MLSS $mlss_id in the db" unless ( defined $mlss->[0] );
} else {
	$mlss = $mlss_a->fetch_all_by_method_link_type('EPO');
}

my @cols = (
	'species_name', 'mlss_id', 'genome_len', 'genome_cov(bp)', 
	'g_cov(%)', 'coding_exon_len', 'coding_exon_cov(bp)', 'e_cov(%)'
);

my $html_output;
if ( $html ) {
	$html_output  = "<table style=\"width:100%\">\n\t<tr>\n\t\t";
	$html_output .= _html_tag_list( \@cols, 'th' );
	$html_output .= "\n\t</tr>\n";

} else {
	$cols[0] .= ' 'x13;
	print join("\t", @cols) . "\n";
}

for my $m ( @$mlss ){
	my $this_species_tree = $dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($m->dbID, 'default');
	for my $g ( @$gdbs ) {
		next if ( $g->name eq 'ancestral_sequences' );
		my $this_genomedb_id = $g->dbID;
		my $stn = $this_species_tree->root->find_leaves_by_field('genome_db_id', $this_genomedb_id)->[0];
		my $coding_exon_bp_coverage = $stn->get_tagvalue("coding_exon_coverage");
		my $coding_exon_length      = $stn->get_tagvalue("coding_exon_length");
		my $genome_bp_coverage      = $stn->get_tagvalue("genome_coverage");
		my $genome_length           = $stn->get_tagvalue("genome_length");

		my $genome_cov_perc = sprintf("%.3f", ($genome_bp_coverage/$genome_length) * 100);
		my $exon_cov_perc   = sprintf("%.3f", ($coding_exon_bp_coverage/$coding_exon_length) * 100);

		if ( $html ) {
			$html_output .= '<tr>' . _html_tag_list( [ $g->name, $m->dbID, _commify($genome_length), _commify($genome_bp_coverage), $genome_cov_perc, _commify($coding_exon_length), _commify($coding_exon_bp_coverage), $exon_cov_perc ], 'td' ) . '</tr>';
		} else {
			print join("\t", _pad_name($g->name), $m->dbID, _commify($genome_length), _commify($genome_bp_coverage), $genome_cov_perc, _commify($coding_exon_length), _commify($coding_exon_bp_coverage), $exon_cov_perc);
			print "\n";
		}
	}
}

if ( $html ) {
	$html_output .= "</table>";
	print "$html_output\n";
}

sub _html_tag_list {
	my ( $list, $tag ) = @_;

	my $output = "<$tag>";
	$output .= join( "</$tag><$tag>", @$list );
	$output .= "</$tag>";

	return $output;
}

sub _commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

sub _pad_name {
	my $name = shift;

	my $padded_len = 25;
	my $pad_needed = $padded_len - length($name);
	my $pad = ' ' x $pad_needed;

	return "$name$pad";
}