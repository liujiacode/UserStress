#!perl
#
# Authors: Liu Jia, Xiang Pan
# Version: 1.1
# Date: 2018.08.25
# Introduction: Calculating energies under strains along a, b and (or) ab directions.
#
# Update
# v1.0: inititalized UserStress. 2018.08.25
# v1.1: correct the file names. 2018.10.29
#
# Website
# https://github.com/liujiacode/UserStress
#

use strict;
use Getopt::Long;
use MaterialsScript qw(:all);

# initializing args.
my %Args;
GetOptions(\%Args, "stress_list=s", "along_a=i", "along_b=i", "along_ab=i", "module=s", "settings=s");
my @stress = eval("$Args{stress_list}");
my $stress_size = @stress;
my $cal_a = $Args{along_a};
my $cal_b = $Args{along_b};
my $cal_ab = $Args{along_ab};
my $module = $Args{module};
my $settings = $Args{settings};

# initializing module.
my $cal_module = "U";
if ($module eq "CASTEP"){
  $cal_module = Modules->CASTEP;
}elsif ($module eq "DMol3"){
  $cal_module = Modules->DMol3;
}
$cal_module->LoadSettings($settings);

# mrun(structure.xsd).
sub mrun {
  my $results = $cal_module->GeometryOptimization->Run($_[0]);
  my $total_energy = $results->TotalEnergy * 0.001593601449;
  my $converged = $results->Converged;
  $cal_module->SaveSettings("saved_settings");
  return ($total_energy, $converged);
}

# initializing sum_energy file.
my $sum_tab = Documents->New("Summary.std");
$sum_tab->ActiveSheet->Title = "a axis";
$sum_tab->InsertSheet(1, "b axis");
$sum_tab->InsertSheet(2, "ab axes");

foreach my $i ((0..2)){
  my $sht = $sum_tab->Sheets($i);
  $sht->InsertColumn(8);
  $sht->ColumnHeading("A") = "Structure";
  $sht->ColumnHeading("B") = "Axis";
  $sht->ColumnHeading("C") = "Stress (%)";
  $sht->ColumnHeading("D") = "a (A)";
  $sht->ColumnHeading("E") = "b (A)";
  $sht->ColumnHeading("F") = "Total Energy (Ha)";
  $sht->ColumnHeading("G") = "Is Converged";
}

# mlog(Structure, Axis, Stress, a, b Total_Energy, Is_Converged).
my @row_indexes = (0, 0, 0);
sub mlog {
  my $is_converged = "False";
  if ($_[6]){
    $is_converged = "True";
  }
  
  my $sht_index = 0;
  if ($_[1] eq "B"){
    $sht_index = 1;
  }elsif ($_[1] eq "AB"){
    $sht_index = 2;
  }
  
  $sum_tab->Sheets($sht_index)->InsertRow();
  foreach my $i ((0..5)){
    $sum_tab->Sheets($sht_index)->Cell($row_indexes[$sht_index], $i) = $_[$i];
  }
  $sum_tab->Sheets($sht_index)->Cell($row_indexes[$sht_index], 6) = $is_converged;
  
  $row_indexes[$sht_index] += 1;
}

# initializing original structure.xsd.
my $ori_doc = Documents->ActiveDocument;
$ori_doc->MakeP1;
my $ori_doc_bak = $ori_doc;
my @init_results = mrun($ori_doc);
my $lattice = $ori_doc->SymmetryDefinition;
my $ori_a = $lattice->LengthA;
my $ori_b = $lattice->LengthB;

# calculating stress along a axis.
if ($cal_a){
  for (my $i = -1; $i >= -1 * $stress_size; $i-=1){
    my $new_a = $ori_a * (1 - $stress[$i]);
    $ori_doc->SymmetryDefinition->LengthA = $new_a;
    $ori_doc->SymmetryDefinition->LengthB = $ori_b;
    my $cha_doc = $ori_doc->SaveAs(".\\a\\n-$stress[$i]\\n-$stress[$i].xsd");
    my @mresults = mrun($cha_doc);
    mlog($cha_doc, "A", -1 * $stress[$i] * 100, $new_a, $ori_b,  $mresults[0], $mresults[1]);
    $cha_doc->Close;
  }
  mlog($ori_doc_bak, "A", 0.00, $ori_a, $ori_b, $init_results[0], $init_results[1]);
  for (my $i = 0; $i < $stress_size; $i+=1){
    my $new_a = $ori_a * (1 + $stress[$i]);
    $ori_doc->SymmetryDefinition->LengthA = $new_a;
    $ori_doc->SymmetryDefinition->LengthB = $ori_b;
    my $cha_doc = $ori_doc->SaveAs(".\\a\\p$stress[$i]\\p$stress[$i].xsd");
    my @mresults = mrun($cha_doc);
    mlog($cha_doc, "A", $stress[$i] * 100, $new_a, $ori_b, $mresults[0], $mresults[1]);
    $cha_doc->Close;
  }
}

# calculating stress along b axis.
if ($cal_b){
  for (my $i = -1; $i >= -1 * $stress_size; $i-=1){
    my $new_b = $ori_b * (1 - $stress[$i]);
    $ori_doc->SymmetryDefinition->LengthA = $ori_a;
    $ori_doc->SymmetryDefinition->LengthB = $new_b;
    my $cha_doc = $ori_doc->SaveAs(".\\b\\n-$stress[$i]\\n-$stress[$i].xsd");
    my @mresults = mrun($cha_doc);
    mlog($cha_doc, "B", -1 * $stress[$i] * 100, $ori_a, $new_b, $mresults[0], $mresults[1]);
    $cha_doc->Close;
  }
  mlog($ori_doc_bak, "B", 0.00, $ori_a, $ori_b, $init_results[0], $init_results[1]);
  for (my $i = 0; $i < $stress_size; $i+=1){
    my $new_b = $ori_b * (1 + $stress[$i]);
    $ori_doc->SymmetryDefinition->LengthA = $ori_a;
    $ori_doc->SymmetryDefinition->LengthB = $new_b;
    my $cha_doc = $ori_doc->SaveAs(".\\b\\p$stress[$i]\\p$stress[$i].xsd");
    my @mresults = mrun($cha_doc);
    mlog($cha_doc, "B", $stress[$i] * 100, $ori_a, $new_b, $mresults[0], $mresults[1]);
    $cha_doc->Close;
  }
}

# calculating stress along ab axis.
if ($cal_ab){
  for (my $i = -1; $i >= -1 * $stress_size; $i-=1){
    my $new_a = $ori_a * (1 - $stress[$i]);
    my $new_b = $ori_b * (1 - $stress[$i]);
    $ori_doc->SymmetryDefinition->LengthA = $new_a;
    $ori_doc->SymmetryDefinition->LengthB = $new_b;
    my $cha_doc = $ori_doc->SaveAs(".\\ab\\n-$stress[$i]\\n-$stress[$i].xsd");
    my @mresults = mrun($cha_doc);
    mlog($cha_doc, "AB", -1 * $stress[$i] * 100, $new_a, $new_b, $mresults[0], $mresults[1]);
    $cha_doc->Close;
  }
  mlog($ori_doc_bak, "AB", 0.00, $ori_a, $ori_b, $init_results[0], $init_results[1]);
  for (my $i = 0; $i < $stress_size; $i+=1){
    my $new_a = $ori_a * (1 + $stress[$i]);
    my $new_b = $ori_b * (1 + $stress[$i]);
    $ori_doc->SymmetryDefinition->LengthA = $new_a;
    $ori_doc->SymmetryDefinition->LengthB = $new_b;
    my $cha_doc = $ori_doc->SaveAs(".\\ab\\p$stress[$i]\\p$stress[$i].xsd");
    my @mresults = mrun($cha_doc);
    mlog($cha_doc, "AB", $stress[$i] * 100, $new_a, $new_b, $mresults[0], $mresults[1]);
    $cha_doc->Close;
  }
}

$ori_doc->Discard;
$sum_tab->Close;
