-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016] EMBL-European Bioinformatics Institute
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

# patch_83_84_d.sql
#
# Title: Add new a new goc_score and wga_coverage columns to the homology table.
#
# Description:
#   Adding a column to hold the gene order conservation (goc) score. These values are in percentage

-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';
/**
@goc_score                     Gene Order conservation (goc) score in %.
*/

ALTER TABLE homology ADD COLUMN goc_score int(10) unsigned;
ALTER TABLE homology ADD COLUMN wga_coverage DEC(5,2);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_83_84_d.sql|insert_orth_quality_homology_table');
