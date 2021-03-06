#this implements the simulation program for the rvmeta project;
rvmeta.sim <- function(pars.sim)
  {
    hap.pool <- pars.sim$hap.pool; # all samples in 1 pool; a big matrix;
    no.pop <- pars.sim$no.pop;
    maf.cutoff <- pars.sim$maf.cutoff;
    scale.vec <- pars.sim$scale.vec;
    region.len <- pars.sim$region.len; #in the unit of 2kb;
    maf.causal <- pars.sim$maf.causal;
    hap.pool.tmp <- hap.pool;
    maf.vec <- colSums(hap.pool.tmp)/nrow(hap.pool.tmp);
    ix.common <- which(maf.vec>0.05);
    if(length(ix.common)==0 & pars.sim$trait=='Q.cond')
      {
        hap.pool.tmp <- cbind(hap.pool.tmp,(rowSums(hap.pool.tmp)+as.numeric(runif(nrow(hap.pool.tmp))<0.05))>0);
        ix.common <- ncol(hap.pool.tmp);
      }
    hap.pool <- hap.pool.tmp;
    pop.size <- nrow(hap.pool)/no.pop;
    trait <- pars.sim$trait; #B or Q;
    beta1.max <- pars.sim$beta1.max;
    beta1.min <- pars.sim$beta1.min;
    mixcp <- pars.sim$mixcp;
    beta1.common <- pars.sim$beta1.common;
    
    pct.causal <- pars.sim$pct.causal;
    maf.vec <- colSums(hap.pool)/nrow(hap.pool);
    maf.max <- max(maf.vec);
    maf.min <- min(maf.vec);    
    beta1.vec <- beta1.max-(maf.vec-maf.min)/(maf.max-maf.min)*(beta1.max-beta1.min);
    if(mixcp>0)
      {
        ix.minus <- sample(1:length(beta1.vec),as.integer(length(beta1.vec)*mixcp));
        beta1.vec[ix.minus] <- beta1.vec[ix.minus]*(-1);
      }
    ind.noncausal <- sample(1:length(beta1.vec),length(beta1.vec)*(1-pct.causal));
    if(length(maf.causal)>0) ind.noncausal <- unique(c(ind.noncausal,which(maf.vec>maf.causal)));
    beta1.vec[ind.noncausal] <- 0;
    if(trait=='Q.cond') beta1.vec[ix.common[1]] <- beta1.common 
    wt.pen <- pars.sim$wt.pen;
    no.sample <- pars.sim$no.sample;#if B, then split into equal numbers of cases and controls;
    if(length(no.sample)!=no.pop) no.sample <- rep(no.sample[1],no.pop);
    no.case <- no.sample/2;no.ctrl <- no.sample/2;
    multi.dat.ped <- list();
    multi.sumstat <- list();
    if(length(scale.vec)==0) 
      scale.vec <- rnorm(no.pop,1,0.5);
    if(trait=='Q' | trait=='Q.cond')
      {
        for(ii in 1:no.pop)
          {
            hap.mat <- hap.pool[(pop.size*(ii-1)+1):(pop.size*ii),];
            genotype <- matrix(NA,nrow=no.sample[ii],ncol=ncol(hap.mat));
            phenotype <- vector(length=no.sample[ii]);
            for(jj in 1:(no.sample[ii]))
              {
                hap1 <- hap.mat[sample(1:nrow(hap.mat),1),];
                hap2 <- hap.mat[sample(1:nrow(hap.mat),1),];
                geno <- hap1+hap2;
                genotype[jj,] <- geno;
                mu <- sum(geno*beta1.vec*(scale.vec[ii]));
                phenotype[jj] <- rnorm(1,mu,1);               
              }
            phenotype.ori <- phenotype;
            phenotype <- qqnorm(phenotype,plot.it=FALSE)$x;
            dat.ped <- list(genotype=genotype,
                            phenotype=phenotype,
                            phenotype.ori=phenotype.ori);
            multi.dat.ped[[ii]] <- dat.ped;                      
          }
      }
    if(trait=='B')
      {
        for(ii in 1:no.pop)
          {
            id.pool <- sample(1:no.pool,1);
            hap.mat <- hap.pool[(pop.size*(ii-1)+1):(pop.size*ii),];
            genotype <- matrix(NA,nrow=no.sample,ncol=ncol(hap.mat));
            phenotype <- vector(length=no.sample);  
            case.count <- 0;ctrl.count <- 0;
            while(case.count<no.case | ctrl.count<no.ctrl)
              {
                hap1 <- hap.mat[sample(1:nrow(hap.mat),1),];
                hap2 <- hap.mat[sample(1:nrow(hap.mat),1),];
                geno <- hap1+hap2;
                genotype.tmp <- geno;
                mu <- log(wt.pen/(1-wt.pen))+sum(genotype.tmp*beta1.vec);
                phenotype.tmp <- (runif(1)<(exp(mu)/(1+exp(mu))));
                if(phenotype.tmp==1 & case.count<no.case)
                  {
                    genotype[case.count+ctrl.count+1,] <- genotype.tmp;
                    phenotype[case.count+ctrl.count+1] <- phenotype.tmp;
                    case.count <- case.count+1;
                  }
                if(phenotype.tmp==1 & ctrl.count<no.ctrl)
                  {
                    genotype[case.count+ctrl.count+1,] <- genotype.tmp;
                    phenotype[case.count+ctrl.count+1] <- phenotype.tmp;
                    ctrl.count <- ctrl.count+1;
                  }
              }
            dat.ped <- list(genotype=genotype,
                            phenotype=phenotype);
            sumstat.ii <- sumstat(dat.ped);
            multi.dat.ped[[ii]] <- dat.ped;
            multi.sumstat[[ii]] <- sumstat.ii;
          }  
      }
    dat.ped.all <- multi.dat.ped[[1]];
    if(length(multi.dat.ped)>1)
      {
        for(ii in 2:length(multi.dat.ped))
          {
            dat.ped.all$genotype <- rbind(dat.ped.all$genotype,(multi.dat.ped[[ii]])$genotype);
          }
      }
    
    maf.vec <- colSums(dat.ped.all$genotype)/nrow(dat.ped.all$genotype)/2;
    ix.rare <- which(maf.vec<maf.cutoff & maf.vec>0);
    if(trait=='Q.cond') ix.rare <- c(ix.rare,ix.common[1]);
    dat.ped.all$genotype <- as.matrix((dat.ped.all$genotype)[,ix.rare]);
    ix.keep <- 1:ncol(dat.ped.all$genotype);
    a=Sys.time();
    if(length(ix.keep)>1)
      {
        res.prune <- prune.ped(dat.ped.all);
        ix.keep <- res.prune$ix.keep;
      }
    sumstat.list <- list();
    for(ii in 1:length(multi.dat.ped))
      {
        multi.dat.ped[[ii]]$genotype <- as.matrix(as.matrix((as.matrix((multi.dat.ped[[ii]])$genotype)[,ix.rare]))[,ix.keep]);
        sumstat.list[[ii]] <- rvmeta.sumstat(multi.dat.ped[[ii]]);
      }
    return(list(dat.ped.list=multi.dat.ped,
                sumstat.list=sumstat.list));
  }
rvmeta.sumstat <- function(dat.ped)
  {
    #obtain individual level statistics;
    genotype <- dat.ped$genotype;
    maf.vec <- colSums(genotype)/nrow(genotype)/2;
    phenotype <- dat.ped$phenotype;
    cov.mat <- cov(genotype);
    y <- phenotype-mean(phenotype);
    N <- length(y);
    cov.mat <- cov.mat*(N-1)/N;
    #score.stat.vec <- 1/sqrt(N)*(t(genotype)%*%y)/sqrt(var(y)*diag(cov.mat));
    score.stat.vec <- 0;
    for(ii in 1:nrow(cov.mat))
      {
        score.stat.vec[ii] <- sqrt(N)*cor(genotype[,ii],y);
      }
    direction.vec <- 2*as.numeric(score.stat.vec>0)-1;
    score.stat.sq.vec <- score.stat.vec^2;    
    res <- list(score.stat.sq.vec=score.stat.sq.vec,
                direction.vec=direction.vec,
                cov.mat=cov.mat,
                var.Y=mean((y-mean(y))^2),
                mean.Y=mean(phenotype),
                N=N,
                maf.vec=maf.vec);
    return(res);
  }
popgen.stat <- function(dat.ped.list)
  {
    #want to compute some summary level statistics for the population genetic simulation;
    ix.sites.l1.list <- list();
    ix.sites.1.5.list <- list();
    ix.sites.g5.list <- list();
    no.sites.vec <- integer(0);
    for(ii in 1:length(dat.ped.list))
      {
        dat.ped <- dat.ped.list[[ii]];
        marker <- dat.ped$genotype;
        maf.vec <- colSums(marker)/nrow(marker)/2;
        ix.sites.l1.list[[ii]] <- which(maf.vec>0 & maf.vec<0.01);
        ix.sites.1.5.list[[ii]] <- which(maf.vec>0.01 & maf.vec<0.03);
        ix.sites.g5.list[[ii]] <- which(maf.vec>0.03);
        no.sites.vec <- c(no.sites.vec,
                          length(ix.sites.l1.list[[ii]]),
                          length(ix.sites.1.5.list[[ii]]),
                          length(ix.sites.g5.list[[ii]]));
      }
    mat.l1 <- matrix(0,nrow=length(dat.ped.list),ncol=length(dat.ped.list));
    mat.g5 <- mat.l1;
    mat.1.5 <- mat.l1;
    for(ii in 1:length(dat.ped.list))
      {
        for(jj in 1:length(dat.ped.list))
          {
            mat.l1[ii,jj] <- length(set.intersect(ix.sites.l1.list[[ii]],ix.sites.l1.list[[jj]]));
            mat.1.5[ii,jj] <- length(set.intersect(ix.sites.1.5.list[[ii]],ix.sites.1.5.list[[jj]]));
            mat.g5[ii,jj] <- length(set.intersect(ix.sites.g5.list[[ii]],ix.sites.g5.list[[jj]]));
          }
      }
    return(c(no.sites.vec,as.vector(mat.l1),as.vector(mat.1.5),as.vector(mat.g5)));
  }
#' Intersection of two sets;
#'
#' @param set1 The set 1
#' @param set2 The set 2
#' @return The intersection of set1 and set2;
#' @export
set.intersect <- function(set1,set2)
  {
    set1 <- unique(set1);
    set2 <- unique(set2)
    set.cup <- c(set1,set2);
    set.cup.tab <- table(set.cup);
    set.cap <- (names(set.cup.tab)[set.cup.tab==2]);
    return(set.cap);
  }
prune.ped <- function(dat.ped,r2.cutoff=1-1e-5)
  {
    genotype <- dat.ped$genotype;
    cov.mat <- cor(genotype);
    ix.rm <- integer(0);
    for(ii in 1:(nrow(cov.mat)-1))
      {
        for(jj in (ii+1):ncol(cov.mat))
          {
            if(is.na(cov.mat[ii,jj])) ix.rm <- c(ix.rm,ii);
            if(!is.na(cov.mat[ii,jj]))
              {
                if(cov.mat[ii,jj]>r2.cutoff) {
                  if(length(which(ix.rm==ii))==0 & length(which(ix.rm==jj))==0)
                    ix.rm <- c(ix.rm,ii);
                }
              }
          }
      }
    ix.keep <- 1:nrow(cov.mat);
    if(length(ix.rm)>0) ix.keep <- ix.keep[-ix.rm];
    return(list(ix.keep=ix.keep,ix.rm=ix.rm));
  }

