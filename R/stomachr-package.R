#' @keywords internal
"_PACKAGE"

#' @importFrom utils head
NULL

utils::globalVariables(c(
  "tbl_upload_id", "tbl_haul_id", "tbl_predator_information_id",
  "tbl_prey_information_id", "aphia_id", "aphia_id_predator", "aphia_id_prey",
  "country", "survey", "year", "month", "day", "time", "lat", "lon",
  "ices_rectangle", "depth", "analysing_org",
  "regurgitated", ".regurg_flag", "stomach_status",
  "pred_length", "ind_wgt", "ind_weight_est", "predator_weight",
  "predator_weight_estimated", "age", "sex",
  "predator_scientific_name", "predator_class", "predator_order",
  "predator_family", "predator_phylum",
  "prey_scientific_name", "prey_class", "prey_order", "prey_family",
  "prey_phylum", "digestion_stage", "sub_factor", "count", "count_censored",
  "prey_length", "prey_weight_ind", "prey_weight_all_ind", "other_wgt",
  "lw_a", "lw_b", "lw_source", "prey_lw_source",
  "pred_lw_a", "pred_lw_b", "pred_lw_source",
  "lw_a_fb", "lw_b_fb", "lw_source_fb", ".a", ".b", ".src", ":=",
  ".wg_weight", ".wg_length", ".fill_weight", ".fill_length", ".size_src",
  "wg1_weight", "wg2_weight", "wg3_weight", "wg1_length", "wg2_length", "wg3_length",
  "obs1_length", "obs1_weight", "obs2_length", "obs2_weight", "obs3_length", "obs3_weight",
  "sense_flag", "stomach_total", "n", "label",
  ".f_prey_length", ".f_prey_weight", ".f_stomach_wgt",
  ".f_pred_length", ".f_count_cens", ".f_coord",
  "worms_lookup", "lw_params",
  "n_stomachs", "X", "Y", ".data",
  "ice_srectangle", "shoot_lat", "shoot_long", "ident_met", "grav_method",
  "prey_sequence", "unit_wgt", "weight", "unit_lngt", "other_items",
  "other_count", "coords", "shoot_lat_imp", "shoot_long_imp"
))
