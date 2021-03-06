#' Function that implement gene-level tests
#' @export 
rvmeta.CMH <- function(score.stat.vec.list,maf.vec.list,cov.mat.list,var.Y.list,N.mat,alternative=c('two.sided','greater','less'),no.boot,alpha=0.05,rv.test,extra.pars=list())
  {

      if(length(alternative)>1) alternative <- "two.sided";
      res.list <- list();
      X.T.times.Y.centered.list <- list();
      X.T.times.X.list <- list();
      maf.vec <- extra.pars$maf.vec;
      mac.vec <- extra.pars$mac.vec;
      mac.vec.list <- extra.pars$mac.vec.list;
      X.T.times.Y <- rep(0,length(score.stat.vec.list[[1]]));
      X.T.times.X <- matrix(0,nrow=length(score.stat.vec.list[[1]]),ncol=length(score.stat.vec.list[[1]]));
      direction.burden.by.study.vec <- rep('',length(score.stat.vec.list[[1]]));
      direction.meta.single.var.vec <- rep('',length(score.stat.vec.list));
      ac.vec <- 0;N <- 0;
      N.list <- list();
      vstat.list <- extra.pars$vstat.list;
      vstat.sq.vec <- 0;
      for(ii in 1:length(score.stat.vec.list))
      {
          N.list[[ii]] <- mean(N.mat[ii,],na.rm=TRUE);
          if(is.na(N.list[[ii]]))
          {
          }
          score.stat.vec.list[[ii]] <- rm.na(score.stat.vec.list[[ii]]);
          
          if(length(vstat.list)==0)
          {
              X.T.times.Y.ii <- (sqrt(N.mat[ii,]))*(score.stat.vec.list[[ii]])*sqrt(diag(cov.mat.list[[ii]]))*sqrt(var.Y.list[[ii]]);
          }
          if(length(vstat.list)>0)
          {
              X.T.times.Y.ii <- score.stat.vec.list[[ii]]*vstat.list[[ii]]
              vstat.sq.vec <- vstat.sq.vec+(rm.na(vstat.list[[ii]]))^2;
          }
          U.ii <- sum(X.T.times.Y.ii,na.rm=TRUE);
          if(is.na(U.ii)) direction.burden.by.study.vec[ii] <- "X";
          if(!is.na(U.ii))
          {
              if(U.ii>0) direction.burden.by.study.vec[ii] <- "+";
              if(U.ii<0) direction.burden.by.study.vec[ii] <- "-";
              if(U.ii==0) direction.burden.by.study.vec[ii] <- "=";
          }
          X.T.times.Y <- X.T.times.Y+ rm.na(X.T.times.Y.ii);
          X.T.times.X <- X.T.times.X+rm.na(N.list[[ii]]*(cov.mat.list[[ii]])*(var.Y.list[[ii]]));
          var.Y.list[[ii]] <- 1;
          X.T.times.X.list[[ii]] <- N.list[[ii]]*(cov.mat.list[[ii]])*(var.Y.list[[ii]]);
          X.T.times.Y.centered.list[[ii]] <- sqrt(N.mat[ii,])*(score.stat.vec.list[[ii]])*sqrt(diag(cov.mat.list[[ii]]))*sqrt(var.Y.list[[ii]]);
          ac.vec <- rm.na(maf.vec.list[[ii]]*N.mat[ii,])*2+ac.vec;
          N <- N+rm.na(N.list[[ii]]);
      }
      
      N.vec <- colSums(N.mat,na.rm=TRUE);
      af.vec <- ac.vec/2/N.vec;
      
      for(ii in 1:length(X.T.times.Y))
      {
          U.ii <- X.T.times.Y[ii];
          if(is.na(U.ii)) direction.meta.single.var.vec[ii] <- "X";
          if(!is.na(U.ii))
          {
              if(U.ii>0) direction.meta.single.var.vec[ii] <- "+";
              if(U.ii<0) direction.meta.single.var.vec[ii] <- "-";
              if(U.ii==0) direction.meta.single.var.vec[ii] <- "="; 
          }
      }
      direction.meta.single.var <- paste(direction.meta.single.var.vec,sep='',collapse='');
      direction.burden.by.study <- paste(direction.burden.by.study.vec,sep='',collapse='');
      cov.mat <- X.T.times.X/N;
      
      ustat.vec <- X.T.times.Y;
      
      V <- matrix(X.T.times.X,nrow=length(ustat.vec),ncol=length(ustat.vec));
      singlevar.stat.vec <- ustat.vec^2/diag(V);
      if(length(vstat.list)>0)
      {
          singlevar.stat.vec <- ustat.vec^2/vstat.sq.vec;
      }
      singlevar.stat.vec <- rm.na(singlevar.stat.vec);
      singlevar.pval.vec <- pchisq(singlevar.stat.vec,df=1,lower.tail=FALSE);
    
      ix.best <- which.min(singlevar.pval.vec);
      if(is.na(ix.best)) ix.best <- 1;
      if(length(score.stat.vec.list[[1]])==1)
      {
          statistic <- singlevar.stat.vec;
          p.value <- singlevar.pval.vec;
          beta1.est <- ustat.vec/diag(V);
          beta1.sd <- 1/diag(V);
          var.X <- as.numeric(cov.mat);
            hsq.est <- beta1.est*beta1.est*var.X;
          
          return(list(statistic=statistic,
                        p.value=p.value,
                        no.site=1,
                        maf.cutoff=maf.vec,
                        beta1.est=beta1.est,
                        beta1.sd=beta1.sd,
                        hsq.est=hsq.est,
                        ix.best=ix.best,
                        N=N,
                        nSample=N,
                        X.T.times.X=X.T.times.X,
                        X.T.times.Y=X.T.times.Y,
                        cov=X.T.times.X/N,
                        ustat=X.T.times.Y,
                        vstat=sqrt(diag(X.T.times.X)),
                        singlevar.af.vec=af.vec,
                        singlevar.stat.vec=singlevar.stat.vec,
                        singlevar.pval.vec=singlevar.pval.vec,
                        direction.meta.single.var=direction.meta.single.var,
                        direction.burden.by.study=direction.burden.by.study));
        }
    if(rv.test=='WSS')
        {
            weight <- extra.pars$weight;
            if(length(weight)!=1) weight <- 'MB';
            res <- rvmeta.CMH.wss(list(X.T.times.Y),list(X.T.times.X),maf.vec,list(X.T.times.X/N),list(1),list(N),alternative,no.boot,alpha,weight);

        }
    if(rv.test=='VT')
        {
            res <- rvmeta.CMH.vt(list(X.T.times.Y),list(X.T.times.X),mac.vec,list(X.T.times.X/N),list(1),list(N),alternative,no.boot,alpha,extra.pars=list(max.TH=extra.pars$max.TH));
        }

    if(rv.test=='SKAT')
        {
            kernel <- extra.pars$kernel;
            if(length(kernel)!=1) kernel <- "beta";
            res <- rvmeta.CMH.skat(list(X.T.times.Y),list(X.T.times.X),maf.vec,list(X.T.times.X/N),list(1),list(N),alternative,no.boot,alpha,kernel);
        }
    ix.var <- 1:length(maf.vec);

    if(rv.test=='VT')
        {
            ix.var <- which(mac.vec<=res$mac.cutoff+0.1);
            for(ii in 1:length(score.stat.vec.list))
                {
                    X.T.times.Y.ii <- (sqrt(N.mat[ii,]))*(score.stat.vec.list[[ii]])*sqrt(diag(cov.mat.list[[ii]]))*sqrt(var.Y.list[[ii]]);
                    U.ii <- sum(X.T.times.Y.ii[ix.var],na.rm=TRUE);
                    if(is.na(U.ii)) direction.burden.by.study.vec[ii] <- "X";
                    if(!is.na(U.ii))
                        {
                            if(U.ii>0) direction.burden.by.study.vec[ii] <- "+";
                            if(U.ii<0) direction.burden.by.study.vec[ii] <- "-";
                            if(U.ii==0) direction.burden.by.study.vec[ii] <- "=";
                        }
                }
            X.T.times.Y.new <- X.T.times.Y[ix.var];
            direction.meta.single.var.vec <- rep("X",length(ix.var));
            for(ii in 1:length(X.T.times.Y.new))
                {
                    U.ii <- X.T.times.Y.new[ii];
                    if(is.na(U.ii)) direction.meta.single.var.vec[ii] <- "X";
                    if(!is.na(U.ii))
                        {
                            if(U.ii>0) direction.meta.single.var.vec[ii] <- "+";
                            if(U.ii<0) direction.meta.single.var.vec[ii] <- "-";
                            if(U.ii==0) direction.meta.single.var.vec[ii] <- "="; 
                        }
                }
            direction.meta.single.var <- paste(direction.meta.single.var.vec,sep='',collapse='');
            direction.burden.by.study <- paste(direction.burden.by.study.vec,sep='',collapse='');
                        
        }
    w <- rep(1,length(X.T.times.Y));
    if(rv.test=='WSS')
        {
            if(extra.pars$weight=='MB')
                {
                    q <- ((maf.vec)+1/(2*N))*(2*N)/(2*N+2);
                    w <- 1/sqrt(N*q*(1-q));
                }
        }
    beta1.est <- sum((w[ix.var])*(X.T.times.Y[ix.var]))/as.numeric(t(w[ix.var])%*%matrix(X.T.times.X[ix.var,ix.var],ncol=length(ix.var),nrow=length(ix.var))%*%(w[ix.var]));
    beta1.sd <- sqrt(1/as.numeric(t(w[ix.var])%*%matrix(X.T.times.X[ix.var,ix.var],ncol=length(ix.var),nrow=length(ix.var))%*%(w[ix.var])));
    macf.vec <- 2*(maf.vec[ix.var])*(1-maf.vec[ix.var])+(maf.vec[ix.var])*(maf.vec[ix.var]);
    hsq.est <- beta1.est*beta1.est*as.numeric(t(w[ix.var])%*%matrix(X.T.times.X[ix.var,ix.var],ncol=length(ix.var),nrow=length(ix.var))%*%(w[ix.var]));
    beta1.conf.lower <- beta1.est-1.96*beta1.sd;
    beta1.conf.upper <- beta1.est+1.96*beta1.sd;
    ixVar.VT <- NULL;
    if(rv.test=="VT") ixVar.VT <- ix.var;
    return(c(res,list(direction.meta.single.var=direction.meta.single.var,
                      direction.burden.by.study=direction.burden.by.study,
                      beta1.est=beta1.est,
                      beta1.sd=beta1.sd,
                      no.site=length(ix.var),
                      hsq.est=hsq.est,
                      ix.best=ix.best,
                      singlevar.af.vec=af.vec,
                      X.T.times.X=X.T.times.X,
                      X.T.times.Y=X.T.times.Y,
                      ustat=X.T.times.Y,
                      vstat=sqrt(diag(X.T.times.X)),
                      nSample=N,
                      N=N,
                      N.list=N.list,
                      cov=X.T.times.X/N,
                      ixVar.VT=ixVar.VT,
                      singlevar.stat.vec=singlevar.stat.vec,
                      singlevar.pval.vec=singlevar.pval.vec,
                      beta1.conf.lower=beta1.conf.lower,
                      beta1.conf.upper=beta1.conf.upper)));
  }
#' rvmeta.CMH.new which takes ustat, V stat as input;
#'
#' ustat ustat
#' V the matrix of V;
#' maf.vec the vector of minor allele frequencies
#' N sample size;
#' test The rvtests. Choices are GRANVIL, SKAT or VT;
#' @export 
calcGeneLevelTest <- function(ustat,V,maf.vec,N,test="GRANVIL") {
    mac.vec <- as.integer(maf.vec*N);
    if(test=='GRANVIL') {
        res <- rvmeta.CMH.wss(list(ustat),list(V),maf.vec,list(V/N),list(1),list(N),alternative='two.sided',0,0.05,'MZ');
    }
    if(test=='SKAT') {
        res <- rvmeta.CMH.skat(list(ustat),list(V),maf.vec,list(V/N),list(1),list(N),'two.sided',0,0.05,'beta');
    }
    if(test=='VT') {
        res <- rvmeta.CMH.vt(list(ustat),list(V),mac.vec,list(V/N),list(1),list(N),'two.sided',0,0.05,extra.pars=list(max.TH=10));

    }
    return(res);

}
