#' Use adaptive thresholds to export a set of significantly differentially expressed genes
#'
#' This function outputs lists of differentially expressed genes, according to a set of criteria. It uses the adjusted
#' p-values and log-fold-changes, testing less stringent thresholds until a minimum number of genes are included.
#' It is a wrapper for write_sig_genes.
#' @param topGenes a data frame, typically the output of a call to \code{topTable}. Must contain genes, log2 fold-change, and adjusted p-values.
#' @param file_prefix name of the destination for files. Details of each output will be appended to this prefix.
#' @param method character, specifying the type of gene lists to output. "ranked_list" outputs a list of all genes in ranked order by p-value (from smallest to largest). "combined" outputs a list of all significant genes meeting the threshold. "directional" outputs lists of significant genes meeting the threshold that are up- and down-regulated. Partial matches are allowed.
#' @param adj_p_cut numeric, the cutoff for adjusted p-value. Genes with adjusted p-values greater than or equal to this value are not included in the result. Defaults to 0.01.
#' @param fc_cut numeric, the absolute value cutoff for log2 fold change. Genes with absolute value log2-FC less than or equal to this value are not included in the result. Defaults to log2(1.5). To include all genes, set to 0.
#' @param fc_adj_factor numeric, the adjustment factor used for log2-fold-change values with a numeric predictor. This is included so that the output file names can include the fold change prior to scaling. Defaults to 1, which is the appropriate value for categorical comparisons.
#' @param p_col name or number of the column in \code{topGenes} on which to sort. Generally the raw p-values, as adjusted p-values are often homogenized across a range of raw p-values. Defaults to "P.Value", which corresponds to the output from \code{topTable}. To include all genes, set to >1.
#' @param adj_p_col name or number of the column in \code{topGenes} containing the p-values to compare to \code{p_cut}. Defaults to "adj.P.Val", which corresponds to the output from \code{topTable}.
#' @param fc_col name or number of the column in \code{topGenes} containing the fold-change values to compare to \code{fc_cut}. Defaults to "logFC", which corresponds to the output from \code{topTable}.
# #' @export
#' @details This function writes out lists of genes to text files. By default, it outputs a list ranked by p-value, lists of genes significant based on FDR and logFC thresholds (all, up, and down).
#' @usage \code{
#' write_sig_genes_flexible(
#'   topGenes, file_prefix,
#'   method=c("ranked_list", "combined", "directional"),
#'   adj_p_cut=0.01, fc_cut=log2(1.5), fc_adj_factor=1,
#'   p_col="P.Value", adj_p_col="adj.P.Val", fc_col="logFC")}
write_sig_genes_flexible <-
  function(topGenes, file_prefix,
           method=c("ranked_list", "combined", "directional"),
           adj_p_cut=0.01, fc_cut=log2(1.5), fc_adj_factor=1,
           p_col="P.Value", adj_p_col="adj.P.Val", fc_col="logFC") {
    if (!is.data.frame(topGenes)) stop("topGenes must be a data frame object")
    
    method <- match.arg(method, c("ranked_list", "combined", "directional"), several.ok=TRUE)
    
    topGenes <- topGenes[order(topGenes[,p_col]),] # order topGenes by p-value
    
    if ("ranked_list" %in% method) { # output ranked list
      genes.ranked <- rownames(topGenes)
      write.table(genes.ranked, file=paste0(file_prefix, ".all_genes_ranked_pval.txt"),
                  quote = FALSE, col.names=FALSE, row.names=FALSE)
    }
    
    if (any(c("combined", "directional") %in% method)) {
      if ((fc_cut > 0) & (adj_p_cut <= 1)) {
        threshold_text <- paste0("_FC", round(2^(fc_cut*fc_adj_factor), 3), "_and_P", adj_p_cut)
      } else if (fc_cut > 0) {
        threshold_text <- paste0("_FC", round(2^(fc_cut*fc_adj_factor), 3))
      } else if (adj_p_cut <= 1) { 
        threshold_text <- paste0("_P", adj_p_cut)
      } else {
        threshold_text <- ""
      }
    }
    
    if ("combined" %in% method) { # output combined list of significant genes
      genes.combined <- rownames(topGenes)[
        (topGenes[,adj_p_col] < adj_p_cut) & (abs(topGenes[,fc_col]) > fc_cut)] 
      write.table(genes.combined,
        file=paste0(file_prefix, ".genes", threshold_text, ".txt"),
        quote = FALSE, col.names=FALSE, row.names=FALSE)
    }
    
    if ("directional" %in% method) { # output directional lists of significant genes
      genes.up <- rownames(topGenes)[
        (topGenes[,adj_p_col] < adj_p_cut) & (abs(topGenes[,fc_col]) > fc_cut) &
          (topGenes[,fc_col] > 0)]
      genes.down <- rownames(topGenes)[
        (topGenes[,adj_p_col] < adj_p_cut) & (abs(topGenes[,fc_col]) > fc_cut) &
          (topGenes[,fc_col] < 0)]
      write.table(genes.up,
                  file=paste0(file_prefix, ".genes", threshold_text, ".up.txt"),
                  quote = FALSE, col.names=FALSE, row.names=FALSE)
      write.table(genes.down,
                  file=paste0(file_prefix, ".genes", threshold_text, ".down.txt"),
                  quote = FALSE, col.names=FALSE, row.names=FALSE)
    }
  }
