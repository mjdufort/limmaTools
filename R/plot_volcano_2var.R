#' Generate a volcano plot of genes from a differential expression (limma) analysis
#'
#' Generate a volcano plot of genes from a differential expression (limma) analysis. This plot can be
#' output to a plotting window, or to a pdf. The points can be colored based on fold-change and p-value
#' thresholds. Points can also be labeled with gene names, and the points to be labeled can be set based
#' on an ellipse oriented to the x- and y-axes.
#' @param topGenes a data frame, typically the output of a call to \code{topTable}. Must contain genes, log2 fold-change, and adjusted p-values. Can optionally include a "threshold" column, which should be boolean indicating genes passing significance thresholds.
#' @param my_cols a vector of colors for plotting points. If \code{color_by_threshold} is FALSE, only the first element is used. Otherwise, the first and second elements provide the color for points not exceeding and exceeding significance thresholds, respectively.
#' @param file_prefix a character string. If provided, the function outputs a pdf of the plot, named "{file_prefix}.pdf".
#' @param plotdims a numeric vector, the size (in inches) of the plotting object. Either the size of the pdf, or the size of the plotting window.
#' @param color_by_threshold logical, whether to color points based on exceeding a threshold for logFC and p-value. Used only if fc_cut and p_cut are not NULL.
#' @param fc_cut numeric, the (absolute value) log2 fold-change threshold for determining significance of genes. This value is also plotted as vertical dotted lines. Setting to NULL removes the lines.
#' @param p_cut numeric, the p-value threshold for determining significance of genes. This value is also plotted as a horizontal dotted line. Setting to NULL removes the lines.
#' @param x_lim,y_lim either "auto", NULL, or numeric vectors. If "auto", x- and y-limits are determined from the data using \code{get_xy_lims}. If NULL, default plot limits are used. If provided as numeric vectors, the lower and upper limits of the plotting space along the x- and y-axes. Passed to \code{ggplot2::xlim}.
#' @param gene_labs character, the type of gene labeling to include. If \code{"threshold"}. If \code{"ellipse"}, genes with values outside the labeling ellipse will be labeled. Default value is NULL, which yields no gene labeling.
#' @param x_cut,y_cut numeric. Interpretation depends on the value of \code{gene_labs}. If \code{gene_labs == "threshold"}, these values set the thresholds for logFC and adjusted p-value for labeling the genes; genes will be labeled if \code{-log10 adjusted p-value > y_cut} and \code{logFC} falls on the side of x_cut specified by \code{x_cut_direction} (see below). If \code{gene_labs == "threshold"}, the \code{x_cut} and \code{y_cut} specify the radii of the labeling ellipse along the x- and y-axes; genes with values outside the ellipse are labeled with gene names. Both values default to 0, which results in all genes being labeled.
#' @param x_cut_direction character. For threshold-based gene labeling only, specifies the direction of the threshold for gene labeling. Default to "both", which labels genes with absolute value logFC greater than x_cut. "lower" labels genes with logFC less than x_cut; "upper" labels genes with logFC greater than x_cut.
#' @param gene_labs_repel logical, whether to force separation of the gene label text. If TRUE, labels are plotted using \code{geom_text_repel}.
#' @param gene_lab_size numeric, the size of the gene label text. Passed to \code{geom_text} to \code{geom_text_repel}.
#' @param ... additional parameters passed to \code{pdf}.
#' @import ggplot2
#' @import ggrepel
#' @export
#' @usage \code{
#' plot_volcano_2var(
#'      topGenes, my_cols=c("darkcyan", "darkorange"),
#'      file_prefix=NULL, plotdims=c(9,9),
#'      color_by_threshold=TRUE, fc_cut=log2(1.5), p_cut=0.01,
#'      x_lim="auto", y_lim="auto",
#'      gene_labs=NULL, x_cut=0, y_cut=0, x_cut_direction="both",
#'      gene_labs_repel=TRUE, gene_lab_size=3,
#'      ...)}
plot_volcano_2var <-
  function(topGenes, my_cols=c("darkcyan", "darkorange"),
           file_prefix=NULL, plotdims=c(9,9),
           color_by_threshold=TRUE, fc_cut=log2(1.5), p_cut=0.01,
           x_lim="auto", y_lim="auto",
           gene_labs=NULL, x_cut=0, y_cut=0, x_cut_direction="both",
           gene_labs_repel=TRUE, gene_lab_size=3,
           ...) {
    if (color_by_threshold & (is.null(fc_cut) | is.null(p_cut)))
      stop("Cannot plot points by threshold with null values of fc_cut or p_cut.")
    if (identical(x_lim, "auto") | identical(y_lim, "auto")) {
      xy_lims <- get_xy_lims(topGenes, min_x_abs=fc_cut, min_y2=-log10(p_cut))
      if (identical(x_lim, "auto")) x_lim <- xy_lims[["x"]]
      if (identical(y_lim, "auto")) y_lim <- xy_lims[["y"]]
    }
    
    # add "genes" column to topGenes
    topGenes$genes <- rownames(topGenes)
    
    # if threshold not specified, calculate it
    if (color_by_threshold & is.null(topGenes$threshold))
      topGenes$threshold <- (abs(topGenes$logFC) > fc_cut) & (topGenes$adj.P.Val < p_cut)
    
    # generate volcano plot
    if (color_by_threshold) {
      volcano <-
        ggplot(data = topGenes,
               aes(x=logFC, y=-log10(adj.P.Val), colour=threshold)) +
        geom_point(alpha=0.6, size=3, shape=16) +
        scale_colour_manual(values=my_cols)
    } else {
      volcano <-
        ggplot(data = topGenes,
               aes(x=logFC, y=-log10(adj.P.Val))) +
        geom_point(alpha=0.6, size=3, shape=16, color=my_cols[1])
    }
    volcano <- volcano +
      theme(legend.position = "none") +
      xlab("log2 fold change") + ylab("-log10 Adj P")
    
    if (!is.null(fc_cut)) {
      volcano <- volcano + 
      geom_vline(xintercept = fc_cut, linetype="dotted", size=1.0) +
      geom_vline(xintercept = -fc_cut, linetype="dotted", size=1.0)
    }
    
    if (!is.null(p_cut)) {
      volcano <- volcano +
        geom_hline(yintercept = -log10(p_cut), linetype="dotted",size=1.0)
    }
    
    if (!is.null(x_lim)) {volcano <- volcano + xlim(x_lim)}
    if (!is.null(y_lim)) {volcano <- volcano + ylim(y_lim)}
    
    if (!is.null(gene_labs)) {
      gene_labs <- match.arg(gene_labs, choices=c("ellipse", "threshold"))
      if (gene_labs=="ellipse") {
        topGenes.tmp <-
          topGenes[((topGenes$logFC^2)/(x_cut^2) + (log10(topGenes$adj.P.Val)^2)/(y_cut^2)) > 1,]
      } else if (gene_labs=="threshold") {
        x_cut_direction <- match.arg(x_cut_direction, choices=c("both", "lower", "upper"))
        if (x_cut_direction=="both") {
          topGenes.tmp <-
            topGenes[
              (abs(topGenes$logFC) > x_cut) & (-log10(topGenes$adj.P.Val) > y_cut),]
        } else if (x_cut_direction=="lower") {
          topGenes.tmp <-
            topGenes[
              (topGenes$logFC < x_cut) & (-log10(topGenes$adj.P.Val) > y_cut),]
        } else if (x_cut_direction=="upper") {
          topGenes.tmp <-
            topGenes[
              (topGenes$logFC > x_cut) & (-log10(topGenes$adj.P.Val) > y_cut),]
        }
      }
      
      if (gene_labs_repel) {
        volcano <- volcano +
          geom_text_repel(
            data=topGenes.tmp,
            aes(label=genes),
            color="black", size=gene_lab_size)
      } else {
        volcano <- volcano +
          geom_text(
            data=topGenes.tmp,
            aes(label=genes),
            color="black", size=gene_lab_size, vjust=1, hjust=0.5)
      }
    }
    
    # output volcano plot to file or plot window
    if (!is.null(file_prefix)) {
      pdf(file=paste(file_prefix, "pdf", sep="."), w=plotdims[1], h=plotdims[2], ...)
      on.exit(dev.off(), add=TRUE) # close plotting device on exit
    } else quartz(plotdims[1],plotdims[2])
    print(volcano)
  }
