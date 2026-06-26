#' WoRMS taxonomic lookup table
#'
#' Scientific names and higher taxonomy for every AphiaID that appears in the
#' full ICES stomach content database. Built by `data-raw/build_worms_lookup.R`
#' via the WoRMS API ([worrms::wm_record()]).
#'
#' @format A tibble with columns:
#' \describe{
#'   \item{aphia_id}{WoRMS AphiaID (integer)}
#'   \item{scientific_name}{Scientific name}
#'   \item{rank}{Taxonomic rank (e.g. `"Species"`, `"Genus"`)}
#'   \item{phylum}{Phylum}
#'   \item{class}{Class}
#'   \item{order}{Order}
#'   \item{family}{Family}
#'   \item{genus}{Genus}
#' }
"worms_lookup"

#' Length-weight parameters
#'
#' L/W parameters for prey and predator species, with taxonomic fallback rows
#' at family, order, class, and phylum level. Built by
#' `data-raw/build_lw_params.R`.
#'
#' Formula: \eqn{W_g = a \cdot L_{cm}^b}
#'
#' Sources:
#' - Fish (Chordata): FishBase via [rfishbase::length_weight()], averaged
#'   across parameter sets on the log10 scale.
#' - Invertebrates: Robinson et al. (2010), originally in mm, rescaled to cm.
#'
#' @format A tibble with columns:
#' \describe{
#'   \item{aphia_id}{WoRMS AphiaID (species-level rows only)}
#'   \item{family, order, class, phylum}{Taxonomic group (fallback rows)}
#'   \item{lw_a}{Coefficient \eqn{a} in \eqn{W = a \cdot L^b}}
#'   \item{lw_b}{Exponent \eqn{b}}
#'   \item{lw_source}{One of `"species"`, `"family"`, `"order"`, `"class"`, `"phylum"`}
#' }
#' @references Robinson, R.A. et al. (2010). Trophic relationships of marine
#'   benthic invertebrates in the North Sea. *Journal of the Marine Biological
#'   Association of the United Kingdom*, 90(7), 1375-1388.
"lw_params"
