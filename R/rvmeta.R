RVMETA.pool <- function(scenario=c('gene','region'),score.stat.file,cov.file,gene,test='GRANVIL',maf.cutoff,no.boot=10000,alternative=c('two.sided','greater','less'),alpha=0.05,extra.pars=list(),gene.file="refFlat_hg19.txt.gz")
  {
    capture.output(raw.data.all <- rvmeta.readData( score.stat.file, cov.file, gene.file,gene));
    if(length(raw.data.all)==0)
      return(list(list(p.value=NA,
                       skip=1,
                       statistic=NA,
                       no.var=0,
                       no.sample=NA)));
    res <- list(list(p.value=NA,statistic=NA,no.var=NA,no.sample=NA));
    gene.name <- names(raw.data.all);
    p.value <- double(0);
    ref <- character(0);
    alt <- ref;
    direction.by.study <- character(0);
    ix.gold <- extra.pars$ix.gold;
    if(length(extra.pars$ix.gold)==0) {
      ix.gold <- 1;
    }
    statistic <- double(0);pos <- integer(0);anno <- character(0);direction <- integer(0);res.maf.vec <- double(0);beta1.est.vec <- double(0);beta1.sd.vec <- double(0);
    for(kk in 1:length(raw.data.all))
      {
        raw.data <- raw.data.all[[kk]];
        if(scenario=='gene')
          {
            ix.var <- integer(0);
            if(length(raw.data$ustat[[1]])>0)
              {
                ix.var <- 1:length(raw.data$ustat[[1]])
              }
          }
        if(scenario=='NS')
          {
            ix.var <- integer(0);
            ix.var <- c(ix.var,grep('Nonsynonymous',raw.data$anno));
            ix.var <- sort(unique(ix.var));
          }
        if(scenario=='LOF')
          {
            ix.var <- integer(0);
            ix.var <- c(ix.var,grep('Stop_Gain',raw.data$anno));
            ix.var <- sort(unique(ix.var));
          }
        if(scenario=='NS-LOF')
          {
            ix.var <- integer(0);
            ix.var <- c(ix.var,grep('Stop_Gain|Nonsynonymous',raw.data$anno));
            ix.var <- sort(unique(ix.var));
          }
        if(scenario=='NS-STOP-SPLICE')
          {
            ix.var <- integer(0);
            ix.var <- c(ix.var,grep('Splice|Stop_Loss|Stop_Gain|Nonsynonymous',raw.data$anno));
            ix.var <- sort(unique(ix.var));            
          }
        if(scenario=='region')
          {
            raw.data <- NULL;
            stop("region based meta analysis has not been implemented in this software");
          }
        ix.pop <- length(raw.data$ref);
        pos.list <- list();
        if(length(ix.var)==1) {
          U.stat <- 0;V.stat.sq <- 0;V.stat <- 0;
          N.vec <- 0;
          ref.gold <- raw.data$ref[[ix.gold]][ix.var];
          alt.gold <- raw.data$alt[[ix.gold]][ix.var];
          for(ii in 1:length(ix.pop))
            {
              if(is.na(ref.gold) & !is.na(raw.data$ref[[ii]][ix.var])) {
                ref.gold <- raw.data$ref[[ii]][ix.var];
                alt.gold <- raw.data$alt[[ii]][ix.var];
              }
              N.vec[ii] <- rm.na(as.integer(mean(raw.data$nSample[[ii]],na.rm=TRUE)));
              ref <- (raw.data$ref)[[ii]][ix.var];
              alt <- (raw.data$alt)[[ii]][ix.var];
              pos.list[[ii]] <- (raw.data$pos)[ix.var];
              
              if(!is.na(ref.gold) & !is.na(raw.data$ref[[ii]][ix.var]) )
                {
                  if(ref.gold==(raw.data$ref[[ii]][ix.var]) & alt.gold==(raw.data$alt[[ii]][ix.var]))
                    {
                      U.stat <- U.stat+raw.data$ustat[[ii]][ix.var];
                      V.stat.sq <- V.stat.sq+(raw.data$vstat[[ii]][ix.var])^2;
                    }
                  if(alt.gold==(raw.data$ref[[ii]][ix.var]) & ref.gold==(raw.data$alt[[ii]][ix.var]))
                    {
                      U.stat <- U.stat-raw.data$ustat[[ii]][ix.var];
                      V.stat.sq <- V.stat.sq+(raw.data$vstat[[ii]][ix.var])^2;
                    }
                  if(alternative=='two.sided'){
                    statistic <- U.stat^2/V.stat.sq;
                    p.value <- pchisq(statistic,df=1,lower.tail=FALSE)
                  }
                  if(alternative=='greater'){
                    statistic <- (U.stat/sqrt(V.stat.sq));
                    p.value <- pnorm(statistic,lower.tail=FALSE)
                  }
                  if(alternative=='less'){
                    statistic <- (U.stat/sqrt(V.stat.sq));
                    p.value <- pnorm(statistic,lower.tail=TRUE)
                  }
                }
            }
          anno <- (raw.data$anno)[ix.var];
          
          res[[kk]] <- list(gene.name=gene.name[kk],
                            p.value=p.value,
                            statistic=statistic,
                            no.var=1,
                            no.sample=sum(N.vec),
                            anno=anno,
                            ref=ref.gold,
                            alt=alt.gold,
                            pos=(raw.data$pos)[ix.var]);
        }
        if(length(ix.var)>=2) {
          ix.pop <- 1:length(raw.data$nSample);
          score.stat.vec.list <- list();maf.vec.list <- list();cov.mat.list <- list();var.Y.list <- list();N.list <- list();mean.Y.list <- list();pos.list <- list();anno.list <- list();
          ref.list <- list();
          alt.list <- list();
          for(ii in 1:length(ix.pop))
            {
              U.stat <- rm.na(raw.data$ustat[[ii]]);
              V.stat <- rm.na(raw.data$vstat[[ii]]);
              score.stat.vec.list[[ii]] <- rm.na(U.stat/V.stat);
              N.list[[ii]] <- rm.na(as.integer(mean(raw.data$nSample[[ii]],na.rm=TRUE)));
              cov.mat.list[[ii]] <- rm.na(as.matrix((raw.data$cov[[ii]])[ix.var,ix.var]));
              ix.0 <- which(raw.data$af[[ii]]==0);
              if(length(ix.0)>0) raw.data$af[[ii]][ix.0] <- 1;
              var.Y.list[[ii]] <- 1;
              mean.Y.list[[ii]] <- 0;
              pos.list[[ii]] <- (raw.data$pos)[ix.var];
              ref.list[[ii]] <- (raw.data$ref)[[ii]][ix.var];
              alt.list[[ii]] <- (raw.data$alt)[[ii]][ix.var];
              anno.list[[ii]] <- (raw.data$anno)[ix.var];
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
                              maf.vec.list[[jj]][ii] <- 1-maf.vec.list[[jj]][ii];
                            }
                        }
                    }
                }
            }
          
          maf.vec <- rep(0,length(maf.vec.list[[1]]));
          for(ii in 1:length(ix.pop))
            {
              maf.vec <- maf.vec+(maf.vec.list[[ii]])*(2*N.list[[ii]]);
            }
          maf.vec <- maf.vec/sum(2*unlist(N.list));
          for(ii in 1:length(maf.vec))
            {
              if(maf.vec[ii]>0.5)
                {
                  for(jj in 1:length(ix.pop))
                    {
                      score.stat.vec.list[[jj]][ii] <- (-1)*(score.stat.vec.list[[jj]][ii]);
                      cov.mat.list[[jj]][ii,] <- (-1)*(cov.mat.list[[jj]][ii,]);
                      cov.mat.list[[jj]][,ii] <- (-1)*(cov.mat.list[[jj]][,ii]);
                      maf.vec.list[[jj]][ii] <- 1-maf.vec.list[[jj]][ii];
                    }
                }
            }
          
          ix.rare <- which(maf.vec<maf.cutoff);
          maf.vec.rare <- maf.vec[ix.rare];
          if(length(ix.rare)>1)
            {
              for(ii in 1:length(ix.pop))
                {
                  score.stat.vec.list[[ii]] <- score.stat.vec.list[[ii]][ix.rare];
                  cov.mat.list[[ii]] <- cov.mat.list[[ii]][ix.rare,ix.rare];
                  maf.vec.list[[ii]] <- maf.vec.list[[ii]][ix.rare];
                  anno.list[[ii]] <- anno.list[[ix.gold]][ix.rare];
                  pos.list[[ii]] <- pos.list[[ix.gold]][ix.rare];
                }
              if(test=='WSS')
                {
                  
                  res.kk <- (c(rvmeta.approx.mega(score.stat.vec.list,maf.vec.list,cov.mat.list,mean.Y.list,var.Y.list,N.list,alternative,no.boot,alpha,rv.test='WSS',extra.pars=list(weight='MB'))));
                  res[[kk]] <- c(res.kk,
                                 list(anno=anno.list[[1]],
                                      pos=pos.list[[1]],
                                      ref=ref.list[[ix.gold]],
                                      alt=alt.list[[ix.gold]],
                                      gene.name=gene.name[kk]));
                }
              if(test=='GRANVIL')
                {
                  res.kk <- (c(rvmeta.approx.mega(score.stat.vec.list,maf.vec.list,cov.mat.list,mean.Y.list,var.Y.list,N.list,alternative,no.boot,alpha,rv.test='WSS',extra.pars=list(weight='MZ'))));
                  res[[kk]] <- c(res.kk,
                                 list(anno=anno.list[[ix.gold]],
                                      pos=pos.list[[ix.gold]],
                                      ref=ref.list[[ix.gold]],
                                      alt=alt.list[[ix.gold]],
                                      gene.name=gene.name[kk]));
                }
              if(test=='SKAT-O')
                {
                  res.kk <- (c(rvmeta.approx.mega(score.stat.vec.list,maf.vec.list,cov.mat.list,mean.Y.list,var.Y.list,N.list,alternative,no.boot,alpha,rv.test='SKAT',extra.pars=list(kernel='optimal-beta'))));
                  res[[kk]] <- c(res.kk,
                                 list(anno=anno.list[[1]],
                                      pos=pos.list[[1]],
                                      ref=ref.list[[ix.gold]],
                                      alt=alt.list[[ix.gold]],
                                      gene.name=gene.name[kk]));
                }
              if(test=='SKAT')
                {
                  res.kk <- (c(rvmeta.approx.mega(score.stat.vec.list,maf.vec.list,cov.mat.list,mean.Y.list,var.Y.list,N.list,alternative,no.boot,alpha,rv.test='SKAT',extra.pars=list(kernel='beta'))));
                  res[[kk]] <- c(res.kk,
                                 list(anno=anno.list[[1]],
                                      pos=pos.list[[1]],
                                      ref=ref.list[[ix.gold]],
                                      alt=alt.list[[ix.gold]],
                                      gene.name=gene.name[kk]));
                }
              if(test=='VT')
                {
                  res.kk <- (c(rvmeta.approx.mega(score.stat.vec.list,maf.vec.list,cov.mat.list,mean.Y.list,var.Y.list,N.list,alternative,no.boot,alpha,rv.test='VT',extra.pars=list())));                  
                  res[[kk]] <- c(res.kk,
                                 list(anno=anno.list[[1]],
                                      pos=pos.list[[1]],
                                      ref=ref.list[[ix.gold]],
                                      alt=alt.list[[ix.gold]],
                                      maf.vec=maf.vec.rare,
                                      gene.name=gene.name[kk]));
                }
              if(test=='SINGLE')
                {
                  res.kk <- rvmeta.approx.mega(score.stat.vec.list,maf.vec.list,cov.mat.list,mean.Y.list,var.Y.list,N.list,alternative,no.boot,alpha,rv.test='SINGLE',extra.pars=list());
                  statistic <- c(statistic,res.kk$statistic);
                  direction.by.study <- c(direction.by.study,res.kk$direction.by.study)
                  p.value <- c(p.value,res.kk$p.value);
                  direction <- c(direction,res.kk$direction);
                  res.maf.vec <- c(res.maf.vec,res.kk$maf.vec);
                  beta1.est.vec <- c(beta1.est.vec,res.kk$beta1.est);
                  beta1.sd.vec <- c(beta1.sd.vec,res.kk$beta1.sd);
                  ix.rm <- res.kk$ix.rm;
                  if(length(ix.rm)>0)
                    {
                      anno.list[[1]] <- anno.list[[1]][-ix.rm];
                      pos.list[[1]] <- pos.list[[1]][-ix.rm];
                  }
                anno <- c(anno,anno.list[[ix.gold]]);
                pos <- c(pos,pos.list[[ix.gold]]);
                ref <- c(ref,ref.list[[ix.gold]]);
                alt <- c(alt,alt.list[[ix.gold]]);
              }
              if(test=='SINGLE-inVAR')
              {

                res.kk <- rvmeta.CMH(score.stat.vec.list,maf.vec.list,cov.mat.list,var.Y.list,N.list,alternative,no.boot,alpha,rv.test='SINGLE-inVAR',extra.pars=list());
                statistic <- c(statistic,res.kk$statistic);
                p.value <- c(p.value,res.kk$p.value);
                direction <- c(direction,res.kk$direction);
                res.maf.vec <- c(res.maf.vec,res.kk$maf.vec);
                beta1.est.vec <- c(beta1.est.vec,res.kk$beta1.est);
                beta1.sd.vec <- c(beta1.sd.vec,res.kk$beta1.sd);
                ix.rm <- res.kk$ix.rm;
                if(length(ix.rm)>0)
                  {
                    anno.list[[1]] <- anno.list[[1]][-ix.rm];
                    pos.list[[1]] <- pos.list[[1]][-ix.rm];
                    ref.list[[1]] <- ref.list[[1]][-ix.rm];
                    alt.list[[1]] <- alt.list[[1]][-ix.rm];
                  }
                anno <- c(anno,anno.list[[1]]);
                pos <- c(pos,pos.list[[1]]);
                ref <- c(ref,ref.list[[1]]);
                alt <- c(alt,alt.list[[1]]);
              }
            }
        }
    }
    if(test=='SINGLE' || test=='SINGLE-inVAR')
    {
        res <- list(p.value=p.value,
                    statistic=statistic,
                    direction=direction,
                    maf.vec=res.maf.vec,
                    beta1.est.vec=beta1.est.vec,
                    beta1.sd.vec=beta1.sd.vec,
                    anno=anno,
                    direction.by.study=direction.by.study,
                    pos=pos,
                    ref=ref,
                    alt=alt,
                    raw.data.all=raw.data.all);
    }
    return(res);
}
r2cov.mat <- function(r2.mat,maf.vec)
{
    var.vec <- sqrt(maf.vec*(1-maf.vec)*2);
    var.mat <- (var.vec%*%t(var.vec));
    cov.mat <- r2.mat*var.mat;
    return(cov.mat);
}
