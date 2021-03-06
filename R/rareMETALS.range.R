#' Meta-analysis of gene-level tests by range;
#'
#' @param score.stat.file files of score statistics
#' @param cov.file covariance matrix files
#' @param range tabix range for each gene/region
#' @param range.name The name of the range,e.g. gene names can be used
#' @param test rare variant tests to be used
#' @param maf.cutoff MAF cutoff used to analyze variants
#' @param alternative alternative hypothesis to be specified
#' @param ix.gold Gold standard population to align reference allele to
#' @param out.digits Number of digits used in the output
#' @param callrate.cutoff Cutoffs of call rate, lower than which will NOT be analyzed (labelled as missing)
#' @param hwe.cutoff Cutoffs of HWE p-values
#' @param max.VT The maximum number of thresholds used in VT; Setting max.VT to 10 can improve the speed for calculation without affecting the power too much. The default parameter is NULL, which does not set upper limit on the number of variable frequency threhsold. 
#' @return a list consisting of results
#' @export
rareMETALS.range <- function(score.stat.file,cov.file,range,range.name,test='GRANVIL',maf.cutoff=1,alternative=c('two.sided','greater','less'),ix.gold=1,out.digits=4,callrate.cutoff=0,hwe.cutoff=0,max.VT=NULL)
{
    res <- rareMETALS.range.core(score.stat.file,cov.file,range[1],range.name[1],test,maf.cutoff,alternative,ix.gold,out.digits,callrate.cutoff,hwe.cutoff,max.VT);
    if(length(range)>1)
        {
            for(ii in 2:length(range))
                {
                    cat("Analyzing ",range.name[ii],"\n");
                    res0 <- rareMETALS.range.core(score.stat.file,cov.file,range[ii],range.name[ii],test,maf.cutoff,alternative,ix.gold,out.digits,callrate.cutoff,hwe.cutoff,max.VT)
                    
                    res$res.out <- rbind(res$res.out,res0$res.out);
                    res$res.list <- c(res$res.list,res0$res.list);
                    res$integratedData <- c(res$integratedData,res0$integratedData);
                }
        }
    return(res)
}
#' #' Meta-analysis of gene-level tests by range;
#'
#' @param score.stat.file files of score statistics
#' @param cov.file covariance matrix files
#' @param range tabix range for each gene/region
#' @param range.name The name of the range,e.g. gene names can be used
#' @param test rare variant tests to be used
#' @param maf.cutoff MAF cutoff used to analyze variants
#' @param alternative alternative hypothesis to be specified
#' @param ix.gold Gold standard population to align reference allele to
#' @param out.digits Number of digits used in the output
#' @param callrate.cutoff Cutoffs of call rate, lower than which will NOT be analyzed (labelled as missing)
#' @param hwe.cutoff Cutoffs of HWE p-values
#' @param max.VT The maximum number of thresholds used in VT; Setting max.VT to 10 can improve the speed for calculation without affecting the power too much. The default parameter is NULL, which does not set upper limit on the number of variable frequency threhsold. 
#' @return a list consisting of results
#' @export
rareMETALS.range.core <- function(score.stat.file,cov.file,range,range.name,test='GRANVIL',maf.cutoff=1,alternative=c('two.sided','greater','less'),ix.gold=1,out.digits=4,callrate.cutoff=0,hwe.cutoff=0,max.VT=NULL)
  {
      alpha <- 0.05;
      no.boot <- 0;
    ANNO <- "gene";gene.name <- range.name;
    raw.data.all <- list();
    for(ii in 1:length(range))
      {
        capture.output(raw.data.all[[ii]] <- rvmeta.readDataByRange( score.stat.file, cov.file, range[ii])[[1]]);
      }
    res.null <- list(gene.name=NA,
                     p.value=NA,
                     statistic=NA,
                     no.var=NA,
                     no.sample=NA,
                     anno=NA,
                     ref=NA,
                     alt=NA,
                     maf.cutoff=NA,
                     direction.burden.by.study=NA,
                     direction.meta.single.var=NA,
                     beta1.est=NA,
                     no.site=NA,
                     beta1.sd=NA,
                     hsq.est=NA,
                     pos=NA);
    if(length(raw.data.all)==0)
      {
        res <- list();
        for(ii in 1:length(range.name))
          {
            res.null$gene.name <- range.name[ii];
            res[[ii]] <- res.null;
          }
        
        return(res);        
      }
    res <- list(list(p.value=NA,statistic=NA,no.var=NA,no.sample=NA));
    
    p.value <- double(0);
    ref <- character(0);
    alt <- ref;
    direction.by.study <- character(0);
    statistic <- double(0);pos <- integer(0);anno <- character(0);direction <- integer(0);res.maf.vec <- double(0);beta1.est.vec <- double(0);beta1.sd.vec <- double(0);
    gene.name.out <- range.name;p.value.out <- rep(NA,length(range.name));statistic.out <- rep(NA,length(range.name));no.site.out <- rep(NA,length(range.name));beta1.est.out <- rep(NA,length(range.name));beta1.sd.out <- rep(NA,length(range.name));maf.cutoff.out <- rep(NA,length(range.name));direction.burden.by.study.out <- rep(NA,length(range.name));direction.meta.single.var.out <- rep(NA,length(range.name));pos.ref.alt.out <- rep(NA,length(range.name));top.singlevar.pval <- rep(NA,length(range.name));top.singlevar.refalt <- rep(NA,length(range.name));top.singlevar.pos <- rep(NA,length(range.name));top.singlevar.af <- rep(NA,length(range.name));integratedData <- list();
    for(kk in 1:length(raw.data.all))
      {
        raw.data <- raw.data.all[[kk]];
        raw.data.ori <- raw.data;
        raw.data$gene <- range.name[kk];
        QC.par <- list(callrate.cutoff=callrate.cutoff,hwe.cutoff=hwe.cutoff);
        raw.data <- QC(raw.data,QC.par,cov=1);        
        ix.var <- integer(0);
        if(ANNO=='gene')
          {
            if(length(raw.data$ustat[[1]])>0)
              ix.var <- 1:length(raw.data$ustat[[1]]);
          }
        if(ANNO!='gene')
          {
            if(length(raw.data$ustat[[1]])>0)
              {
                ix.var <- c(ix.var,grep(ANNO,raw.data$anno));
              }
          }
        ix.var <- sort(unique(ix.var));
        if(length(ix.var)==0)
          {
            res.null$gene.name <- gene.name[kk];
            res[[kk]] <- res.null;
          }
        if(length(ix.var)>=1) {
          ix.pop <- 1:length(raw.data$nSample);
          score.stat.vec.list <- list();mac.vec.list <- list();maf.vec.list <- list();cov.mat.list <- list();var.Y.list <- list();N.list <- list();mean.Y.list <- list();pos.list <- list();anno.list <- list();ac.vec.list <- list();af.vec.list <- list();ref.list <- list();alt.list <- list();vstat.list <- list();
          no.sample <- 0;nref.list <- list();nalt.list <- list();nhet.list <- list();
          af.mat <- matrix(NA,ncol=length(raw.data$ustat[[ii]]),nrow=length(raw.data$ustat));
          ac.mat <- af.mat;
          N.mat <- af.mat;
          for(ii in 1:length(ix.pop))
            {
                if(length(raw.data$covXZ[[ii]])>0) {
                    warning(paste0("Study  ",ii," is analyzed as binary trait. It is advised to use rareMETALS2 for meta-analysis"))
                }
                N.list[[ii]] <- rm.na(as.integer(mean(raw.data$nSample[[ii]],na.rm=TRUE)));
              no.sample <- no.sample+N.list[[ii]];
              N.mat[ii,] <- raw.data$nSample[[ii]];
              U.stat <- rm.na(raw.data$ustat[[ii]][ix.var]);
              V.stat <- rm.na(raw.data$vstat[[ii]][ix.var]);
              vstat.list[[ii]] <- V.stat;
              score.stat.vec.list[[ii]] <- rm.na(U.stat/V.stat);              
              cov.mat.list[[ii]] <- as.matrix(rm.na(as.matrix(raw.data$cov[[ii]])[ix.var,ix.var]));
              var.Y.list[[ii]] <- 1;
              mean.Y.list[[ii]] <- 0;
              af.vec.list[[ii]] <- rm.na((raw.data$af[[ii]])[ix.var]);
              ac.vec.list[[ii]] <- rm.na((raw.data$ac[[ii]])[ix.var]);
              af.mat[ii,] <- af.vec.list[[ii]][ix.var];
              ac.mat[ii,] <- ac.vec.list[[ii]][ix.var];
              
              pos.list[[ii]] <- (raw.data$pos)[ix.var];
              ref.list[[ii]] <- (raw.data$ref)[[ii]][ix.var];
              alt.list[[ii]] <- (raw.data$alt)[[ii]][ix.var];
              anno.list[[ii]] <- (raw.data$anno)[ix.var];
              nref.list[[ii]] <- rm.na((raw.data$nref)[[ii]])[ix.var];
              nalt.list[[ii]] <- rm.na((raw.data$nalt)[[ii]])[ix.var];
              nhet.list[[ii]] <- rm.na((raw.data$nhet)[[ii]])[ix.var];
              
            }
          if(length(ix.pop)>1)
            {
              for(ii in 1:length(ix.var))
                {
                  for(jj in (1:length(ix.pop))[-ix.gold])
                    {
                      if(is.na(ref.list[[ix.gold]][ii]) & !is.na(ref.list[[jj]][ii]))
                        {
                          ref.list[[ix.gold]][ii] <- ref.list[[jj]][ii];
                          alt.list[[ix.gold]][ii] <- alt.list[[jj]][ii];
                        }
                      if((is.na(alt.list[[ix.gold]][ii]) | (alt.list[[ix.gold]][ii])=='0' | (alt.list[[ix.gold]][ii])==".") & (!is.na(alt.list[[jj]][ii]) & (alt.list[[jj]][ii]!="0") & (alt.list[[jj]][ii]!=".")))
                        {
                          alt.list[[ix.gold]][ii] <- alt.list[[jj]][ii];
                        }
                      if(!is.na(ref.list[[jj]][ii]) & !is.na(ref.list[[ix.gold]][ii]))
                        {
                          if(ref.list[[jj]][ii]==alt.list[[ix.gold]][ii] & (ref.list[[jj]][ii])!=(ref.list[[ix.gold]][ii]))
                            {
                                tmp <- ref.list[[jj]][ii];
                                ref.list[[jj]][ii] <- alt.list[[jj]][ii];
                                alt.list[[jj]][ii] <- tmp;                              
                                score.stat.vec.list[[jj]][ii] <- (-1)*(score.stat.vec.list[[jj]][ii]);
                                cov.mat.list[[jj]][ii,] <- (-1)*(cov.mat.list[[jj]][ii,]);
                                cov.mat.list[[jj]][,ii] <- (-1)*(cov.mat.list[[jj]][,ii]);
                                af.vec.list[[jj]][ii] <- 1-af.vec.list[[jj]][ii];
                                ac.vec.list[[jj]][ii] <- 2*N.mat[jj,ii]-ac.vec.list[[jj]][ii];
                                af.mat[jj,ii] <- af.vec.list[[jj]][ii];
                                ac.mat[jj,ii] <- ac.vec.list[[jj]][ii];
                                tmp <- nref.list[[jj]][ii];
                                nref.list[[jj]][ii] <- nalt.list[[jj]][ii];
                                nalt.list[[jj]][ii] <- tmp;
                            }
                      }
                  }
              }
          }          


          af.vec <- colSums(af.mat*N.mat,na.rm=TRUE)/colSums(N.mat,na.rm=TRUE);
          ac.vec <- colSums(ac.mat,na.rm=TRUE);
          maf.vec <- af.vec;
          mac.vec <- ac.vec;          
          
          ix.major <- which(af.vec>0.5);
          if(length(ix.major)>0)
            {
              maf.vec[ix.major] <- 1-maf.vec[ix.major];
              mac.vec[ix.major] <- 2*no.sample-ac.vec[ix.major];
              tmp.major <- flip.score.cov(score.stat.vec.list,cov.mat.list,ix.major);
              score.stat.vec.list <- tmp.major$score.stat.vec.list;
              cov.mat.list <- tmp.major$cov.mat.list;
            }
          ix.rare <- which(maf.vec<maf.cutoff & maf.vec>0);          
          maf.vec.rare <- maf.vec[ix.rare];
          mac.vec.rare <- mac.vec[ix.rare];
          
          if(length(ix.rare)==0)
            {
              res.null$gene.name <- gene.name[kk];
              res[[kk]] <- res.null;
            }
          if(length(ix.rare)>=1)
            {
              for(ii in 1:length(ix.pop))
                {
                  score.stat.vec.list[[ii]] <- score.stat.vec.list[[ii]][ix.rare];
                  vstat.list[[ii]] <- vstat.list[[ii]][ix.rare];
                  cov.mat.list[[ii]] <- as.matrix(cov.mat.list[[ii]][ix.rare,ix.rare]);
                  af.vec.list[[ii]] <- af.vec.list[[ii]][ix.rare];
                  ac.vec.list[[ii]] <- ac.vec.list[[ii]][ix.rare];
                  anno.list[[ii]] <- anno.list[[ix.gold]][ix.rare];
                  pos.list[[ii]] <- pos.list[[ix.gold]][ix.rare];
                  ref.list[[ii]] <- ref.list[[ix.gold]][ix.rare];
                  alt.list[[ii]] <- alt.list[[ix.gold]][ix.rare];
                }
              N.mat <- matrix(N.mat[,ix.rare],nrow=nrow(N.mat),ncol=length(ix.rare));
              res.extra <- list(anno=anno.list[[ix.gold]],
                                pos=pos.list[[ix.gold]],
                                ref=ref.list[[ix.gold]],
                                alt=alt.list[[ix.gold]],
                                af.vec.list=af.vec.list,
                                score.stat.vec.list=score.stat.vec.list,
                                cov.mat.list=cov.mat.list,
                                pos.list=pos.list,
                                alt.list=alt.list,
                                ref.list=ref.list,
                                raw.data=raw.data.ori,
                                gene.name=gene.name[kk]);
              if(test=='WSS')
                {
                  res.kk <- (c(rvmeta.CMH(score.stat.vec.list,af.vec.list,cov.mat.list,var.Y.list,N.mat,alternative,no.boot,alpha,rv.test='WSS',extra.pars=list(vstat.list=vstat.list,weight='MB',ac.vec.list=ac.vec.list,
                                                                                                                                                    maf.vec=maf.vec.rare,mac.vec=mac.vec.rare))));
                  res[[kk]] <- c(res.kk,res.extra);
                  res[[kk]]$maf.cutoff <- maf.cutoff;
                }
              if(test=='GRANVIL')
                {
                  res.kk <- (c(rvmeta.CMH(score.stat.vec.list,af.vec.list,cov.mat.list,var.Y.list,N.mat,alternative,no.boot,alpha,rv.test='WSS',extra.pars=list(vstat.list=vstat.list,weight='MZ',ac.vec.list=ac.vec.list,
                                                                                                                                                    maf.vec=maf.vec.rare,mac.vec=mac.vec.rare))));
                  res[[kk]] <- c(res.kk,res.extra);
                  res[[kk]]$maf.cutoff <- maf.cutoff;
                }
              if(test=='SKAT')
                {
                  res.kk <- (c(rvmeta.CMH(score.stat.vec.list,af.vec.list,cov.mat.list,var.Y.list,N.mat,alternative,no.boot,alpha,rv.test='SKAT',extra.pars=list(vstat.list=vstat.list,kernel='beta',ac.vec.list=ac.vec.list,
                                                                                                                                                     maf.vec=maf.vec.rare,mac.vec=mac.vec.rare))));
                  res[[kk]] <- c(res.kk,res.extra);
                  res[[kk]]$maf.cutoff <- maf.cutoff;
                }
              if(test=='VT')
                {
                  res.kk <- (c(rvmeta.CMH(score.stat.vec.list,af.vec.list,cov.mat.list,var.Y.list,N.mat,alternative,no.boot,alpha,rv.test='VT',extra.pars=list(vstat.list=vstat.list,ac.vec.list=ac.vec.list,maf.vec=maf.vec.rare,mac.vec=mac.vec.rare,max.TH=max.VT))));
                  res[[kk]] <- c(res.kk,res.extra);
                }
              gene.name.out[kk] <- res[[kk]]$gene.name;
              p.value.out[kk] <- format(res[[kk]]$p.value,digits=out.digits);
              statistic.out[kk] <- format(res[[kk]]$statistic,digits=out.digits);
              no.site.out[kk] <- res[[kk]]$no.site;
              beta1.est.out[kk] <- format(res[[kk]]$beta1.est,digits=out.digits);
              beta1.sd.out[kk] <- format(res[[kk]]$beta1.sd,digits=out.digits);
              maf.cutoff.out[kk] <- format(res[[kk]]$maf.cutoff,digits=out.digits);
              direction.burden.by.study.out[kk] <- res[[kk]]$direction.burden.by.study;
              direction.meta.single.var.out[kk] <- res[[kk]]$direction.meta.single.var;          
              pos.ref.alt.out[kk] <- paste(res[[kk]]$pos,res[[kk]]$ref,res[[kk]]$alt,sep='/',collapse=',');
              ix.best <- res[[kk]]$ix.best;
              top.singlevar.pos[kk] <- res[[kk]]$pos[ix.best];
              top.singlevar.refalt[kk] <- paste(c(res[[kk]]$ref[ix.best],res[[kk]]$alt[ix.best]),sep="/",collapse="/");
              top.singlevar.pval[kk] <- format(res[[kk]]$singlevar.pval.vec[ix.best],digits=out.digits);
              top.singlevar.af[kk] <- format(res[[kk]]$singlevar.af.vec[ix.best],digits=out.digits);
              ref.out <- list(res[[kk]]$ref);
              alt.out <- list(res[[kk]]$alt);
              nSample.out <- list(rep(res[[kk]]$nSample,length(ref.out[[1]])));
              af.out <- list(res[[kk]]$singlevar.af.vec);
              ac.out <- list(as.integer(af.out[[1]]*nSample.out[[1]]*2));
              callrate <- list(rep(1,length(ref.out[[1]])));
              nref.out <- 0;
              nalt.out <- 0;
              nhet.out <- 0;
              ustat.out <- list(res[[kk]]$ustat);
              vstat.out <- list(res[[kk]]$vstat);
              callrate.out <- list(rep(1,length(ref.out[[1]])));
              hwe.out <- list(rep(1,length(ref.out[[1]])));
              effect.out <- list(ustat.out[[1]]/vstat.out[[1]]^2);
              pVal.out <- list(res[[kk]]$singlevar.pval.vec);
              cov.out <- list(res[[kk]]$cov);
              pos.out <- res[[kk]]$pos;
              anno.out <- res[[kk]]$anno;
              for(aa in 1:length(nref.list))
                {
                  nref.out <- nref.out+nref.list[[aa]];
                  nalt.out <- nalt.out+nalt.list[[aa]];
                  nhet.out <- nhet.out+nhet.list[[aa]];
                }
              nref.out <- list(nref.out);
              nalt.out <- list(nalt.out);
              nhet.out <- list(nhet.out);
              integratedData[[kk]] <- list(ref=ref.out,
                                           alt=alt.out,
                                           nSample=nSample.out,
                                           af=af.out,
                                           ac=ac.out,
                                           callrate=callrate.out,
                                           hwe=hwe.out,
                                           nref=nref.out,
                                           nalt=nalt.out,
                                           ustat=ustat.out,
                                           vstat=vstat.out,
                                           nhet=nhet.out,
                                           effect=effect.out,
                                           pVal=pVal.out,
                                           cov=cov.out,
                                           pos=pos.out,
                                           covZZ=list(matrix(nrow=0,ncol=0)),
                                           covXZ=list(matrix(ncol=0,nrow=length(ref.out[[1]]))),
                                           hweCase=list(rep(NA,length(ref.out[[1]]))),
                                           hweCtrl=list(rep(NA,length(ref.out[[1]]))),
                                           afCtrl=list(rep(NA,length(ref.out[[1]]))),
                                           afCase=list(rep(NA,length(ref.out[[1]]))),
                                           anno=anno.out);
            }
        }
    }
    res.out <- cbind(gene.name.out,p.value.out,statistic.out,no.site.out,beta1.est.out,beta1.sd.out,maf.cutoff.out,direction.burden.by.study.out,direction.meta.single.var.out,top.singlevar.pos,top.singlevar.refalt,top.singlevar.pval,top.singlevar.af,pos.ref.alt.out);
    
    return(list(res.list=res,
                integratedData=integratedData,
                res.out=res.out));
  }

r2cov.mat <- function(r2.mat,maf.vec)
  {
    var.vec <- sqrt(maf.vec*(1-maf.vec)*2);
    var.mat <- (var.vec%*%t(var.vec));
    cov.mat <- r2.mat*var.mat;
    return(cov.mat);
  }
flip.score.cov <- function(score.stat.vec.list,cov.mat.list,ix.major)
  {
    for(ii in 1:length(score.stat.vec.list))
      {
        score.stat.vec.list[[ii]][ix.major] <- (-1)*score.stat.vec.list[[ii]][ix.major];
        cov.mat.list[[ii]][ix.major,] <- (-1)*cov.mat.list[[ii]][ix.major,];
        cov.mat.list[[ii]][,ix.major] <- (-1)*cov.mat.list[[ii]][,ix.major];
      }
    return(list(cov.mat.list=cov.mat.list,
                score.stat.vec.list=score.stat.vec.list));
  }
check.mono <- function(af.vec.list,ac.vec.list,N.list)
  {
    count <- rep(0,length(af.vec.list[[1]]));
    for(ii in 1:length(af.vec.list))
      {
        count <- count+(af.vec.list[[ii]]==1 | af.vec.list[[ii]]==0);
      }
    ix.change <- which(count==length(af.vec.list));
    if(length(ix.change)>0)
      {
        for(ii in 1:length(af.vec.list))
          {
            af.vec.list[[ii]][ix.change] <- 0;
            ac.vec.list[[ii]][ix.change] <- N.list[[ii]]
          }
      }
    return(list(af.vec.list=af.vec.list,
                ac.vec.list=ac.vec.list));
  }
