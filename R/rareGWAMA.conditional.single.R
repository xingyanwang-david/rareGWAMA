#' conditional analysis for single variant association test;
#'
#' @param score.stat.file the file names of score statistic files;
#' @param imp.qual.file the file names of imputation quality;
#' @param vcf.ref.file the file names of the reference panel file;
#' @param candidateVar the tabix range;
#' @param knownVar known variant;
#' @param alternative The alternative hypothesis. Default is two.sided;
#' @param col.impqual The column number for the imputation quality score;
#' @param impQual.lb The lower bound for the imputation quality. Variants with imputaiton quality less than impQual.lb will be labelled as missing;
#' @param impQualWeight Using imputation quality as weight
#' @param rmMultiAllelicSite Default is TRUE. Multi-allelic sites will be removed from the analyses if set TRUE, and a variable posMulti will be output; The variant site with multiple alleles can be analyzed using rareGWAMA.single.multiAllele function; 
#' @return A list of analysis results;
#' @examples 
#' temp <- getwd();
#' setwd(system.file("extdata", package = "rareGWAMA"));
#' study.vec <- c("study1.gz", "study2.gz", "study3.gz");
#' r2.vec <- c("study1.R2.gz", "study2.R2.gz", "study3.R2.gz");
#' res <- rareGWAMA.cond.single(score.stat.file= study.vec, imp.qual.file = r2.vec, vcf.ref.file = "1kg_fra_chr1.vcf.gz", "1:10177", "1:57200", 
#'                              alternative="two.sided",col.impqual=5,impQual.lb=0,impQualWeight=FALSE, weight="Npq+impQ",gc=FALSE, 
#'                              rmMultiAllelicSite=TRUE);
#' head(res$res.formatted);
#' setwd(temp);
#' 
#' @export 
rareGWAMA.cond.single <- function(score.stat.file,imp.qual.file=NULL,vcf.ref.file,candidateVar,knownVar,alternative="two.sided",...) {
    uniq.allele <- function(x) {x.tab <- table(x);return(paste(names(x.tab),sep=',',collapse=','))}
    extraPar <- list(...);
    r2.cutoff <- extraPar$r2.cutoff;
    if(is.null(r2.cutoff)) r2.cutoff <- 0.95;
    sizePerBatch <- extraPar$sizePerBatch;
    if(is.null(sizePerBatch)) sizePerBatch <- 100;
    refGeno <- extraPar$refGeno;
    col.impqual <- extraPar$col.impqual;

    impQual.lb <- extraPar$impQual.lb;
    impQualWeight <- FALSE;
    rmMultiAllelicSite <- extraPar$rmMultiAllelicSite;
    if(is.null(col.impqual)) col.impqual <- 5;
    if(is.null(impQual.lb)) impQual.lb <- 0.7;
    if(is.null(rmMultiAllelicSite)) rmMultiAllelicSite <- TRUE;
    if(is.null(refGeno)) refGeno <- "DS";
    pseudoScore <- extraPar$pseudoScore;
    if(is.null(pseudoScore)) pseudoScore <- TRUE;
    beta.est <- 0;beta.se <- 0;statistic <- 0;p.value <- 0;ref.tab <- 0;alt.tab <- 0;pos.all <- 0;marginal.statistic <- 0;marginal.p.value <- 0;
    ii <- 0;batchEnd <- 0;batchStart <- 0;nSample <- 0;af <- 0;numStability <- 0;
    while(batchEnd<length(candidateVar)) {
        batchStart <- batchEnd+1;
        batchEnd <- batchStart+sizePerBatch;
        if(batchEnd>length(candidateVar)) batchEnd <- length(candidateVar);
        candidateVar.ii <- candidateVar[batchStart:batchEnd];
        tabix.range <- get.tabix.range(c(candidateVar.ii,knownVar));
        a <- Sys.time();
        capture.output(raw.data.all <- rvmeta.readDataByRange( score.stat.file, NULL, tabix.range,multiAllelic = TRUE));
        vcfIndv <- refGeno;
        annoType <- "";
        vcfColumn <- c("CHROM","POS","REF","ALT");
        vcfInfo <- NULL;      
        geno.list <- readVCFToListByRange(vcf.ref.file, tabix.range, "", vcfColumn, vcfInfo, vcfIndv)        
        raw.imp.qual <- NULL;
        if(!is.null(imp.qual.file))
            raw.imp.qual <- lapply(imp.qual.file,tabix.read.table,tabixRange=tabix.range);
        time.readData <- Sys.time()-a;
        b <- Sys.time();
        raw.data.all <- raw.data.all[[1]];
        cat('Read in',length(raw.data.all$ref[[1]]),'variants\n',sep=' ');
        dat <- GWAMA.formatData(raw.data.all,raw.imp.qual,impQualWeight,impQual.lb,col.impqual);
        if(rmMultiAllelicSite==TRUE) {
            tmp <- GWAMA.rmMulti(dat);
            dat <- tmp$dat;posMulti <- tmp$posMulti;
        }
        pos <- gsub("_.*","",dat$pos);
        if(refGeno=="DS") {
            gt <- geno.list$DS;
            gt <- matrix(as.numeric(gt),nrow=nrow(gt),ncol=ncol(gt));
        }
        if(refGeno=="GT") {
            gt.tmp <- geno.list$GT;
   
            gt <- matrix(NA,nrow=nrow(gt.tmp),ncol=ncol(gt.tmp));
            gt[which(gt.tmp=="0/0",arr.ind=T)] <- 0;
            gt[which(gt.tmp=="1/0",arr.ind=T)] <- 1;
            gt[which(gt.tmp=="0/1",arr.ind=T)] <- 1;
            gt[which(gt.tmp=="1/1",arr.ind=T)] <- 2
            gt[which(gt.tmp=="0|0",arr.ind=T)] <- 0;
            gt[which(gt.tmp=="1|0",arr.ind=T)] <- 1;
            gt[which(gt.tmp=="0|1",arr.ind=T)] <- 1;
            gt[which(gt.tmp=="1|1",arr.ind=T)] <- 2
            
        }
        
        r2.tmp <- cor(gt,use='pairwise.complete');
        r2.tmp <- rm.na(r2.tmp);
        pos.vcf <- paste(geno.list$CHROM,geno.list$POS,sep=":");
        r2 <- matrix(0,nrow=length(pos),ncol=length(pos));
        r2 <- as.matrix(r2.tmp[match(pos,pos.vcf),match(pos,pos.vcf)]);
        colnames(r2) <- pos;
        diag(r2) <- 1;
        for(kk in 1:length(candidateVar.ii)) {
            batchId <- (batchStart:batchEnd)[kk];
            ix.candidate <- match(intersect(pos,candidateVar.ii[kk]),pos);        
            ix.known <- match(intersect(pos,knownVar),pos);
            res.cond <- list();
            cond.ok <- 0;
            statistic[batchId] <- NA;
            p.value[batchId] <- NA;
            beta.est[batchId] <- NA;
            beta.se[batchId] <- NA;
            numStability[batchId] <- 0;
            nSample[batchId] <- NA;
            pos.all[batchId] <- NA;
            ref.tab[batchId] <- NA;
            alt.tab[batchId] <- NA;
            af[batchId] <- NA;
            if(length(ix.candidate)>0 & length(ix.known)>0) {
                ref.tab[batchId] <- apply(matrix(dat$ref.mat[ix.candidate,],nrow=1),1,uniq.allele);
                alt.tab[batchId] <- apply(matrix(dat$alt.mat[ix.candidate,],nrow=1),1,uniq.allele);
                pos.all[batchId] <- pos[ix.candidate];
                numStability[batchId] <- (length(which(abs(r2[ix.candidate,ix.known])>r2.cutoff))==0 && !is.na(sum(abs(r2[ix.candidate,ix.known]))))
                af.meta <- rowSums((dat$af.mat)*(dat$nSample.mat),na.rm=T)/rowSums((dat$nSample.mat),na.rm=T);
                af[batchId] <- af.meta[ix.candidate];
            }
            if(length(ix.candidate)>0 & length(ix.known)>0) {
                if(pseudoScore==TRUE) {
                    dat$ustat.mat.ori <- dat$ustat.mat;
                    dat$vstat.mat.ori <- dat$vstat.mat;
                    dat$z.mat <- dat$ustat.mat/dat$vstat.mat;
                    dat$vstat.mat <- sqrt(2*dat$af.mat*(1-dat$af.mat)*dat$nSample.mat)*dat$w.mat;
                    dat$ustat.mat <- (dat$z.mat)*(dat$vstat.mat);
                    res.cond <- getCondUV(dat=dat,lambda=extraPar$lambda,ix.candidate=ix.candidate,ix.known=ix.known,r2=r2);
                    cond.ok <- 1;
                    
                    if(res.cond$numStability==0) {
                        numStability[batchId] <- 0;
                        cond.ok <- 0
                    }
                    
                }
                
                if(pseudoScore==FALSE) {
                    tmp.ustat <- matrix(dat$ustat.mat[c(ix.candidate,ix.known),],nrow=length(ix.candidate)+length(ix.known));
                    ix.missing <- which(colSums(is.na(tmp.ustat))>0);
                    dat.rmMissing <- dat;
                    if(length(ix.missing)==0) {
                        res.cond <- getCondUV(dat=dat.rmMissing,lambda=extraPar$lambda,ix.candidate=ix.candidate,ix.known=ix.known,r2=r2);
                        cond.ok <- 1;
                    }
                    if(length(ix.missing)>0 & length(ix.missing)<ncol(dat$ustat.mat)) {
                        dat.rmMissing$ustat.mat <- matrix(dat$ustat.mat[,-ix.missing],ncol=ncol(dat$ustat.mat)-length(ix.missing));
                        dat.rmMissing$vstat.mat <- matrix(dat$vstat.mat[,-ix.missing],ncol=ncol(dat$ustat.mat)-length(ix.missing));
                        res.cond <- getCondUV(dat=dat.rmMissing,lambda=extraPar$lambda,ix.candidate=ix.candidate,ix.known=ix.known,r2=r2);
                        cond.ok <- 1;
                    }
                }
                if(cond.ok==1) {
                    statistic[batchId] <- (res.cond$conditional.ustat)^2/diag(res.cond$conditional.V);
                    marginal.statistic[batchId] <- (sum(dat$ustat.mat[ix.candidate,],na.rm=TRUE))^2/sum((dat$vstat.mat[ix.candidate,])^2,na.rm=TRUE);
                    marginal.p.value[batchId] <- pchisq(marginal.statistic[batchId],df=1,lower.tail=FALSE)
                    p.value[batchId] <- pchisq(statistic[batchId],df=1,lower.tail=F);
                    beta.est[batchId] <- res.cond$conditional.beta.est;
                    beta.se[batchId] <- sqrt(diag(res.cond$conditional.beta.var));
                    
                    nSample[batchId] <- res.cond$nSample[ix.candidate];
                    ref.tab[batchId] <- apply(matrix(dat$ref.mat[ix.candidate,],nrow=1),1,uniq.allele);
                    alt.tab[batchId] <- apply(matrix(dat$alt.mat[ix.candidate,],nrow=1),1,uniq.allele);
                    pos.all[batchId] <- pos[ix.candidate];
                    af.meta <- rowSums((dat$af.mat)*(dat$nSample.mat),na.rm=T)/rowSums((dat$nSample.mat),na.rm=T);
                    af[batchId] <- af.meta[ix.candidate];
                }
                
            }
        }
    }
    res.formatted <- cbind(pos.all,
                           ref.tab,
                           alt.tab,
                           format(af,digits=3),
                           format(statistic,digits=3),
                           format(p.value,digits=3),
                           format(beta.est,digits=3),
                           format(beta.se,digits=3),
                           nSample,
                           numStability);
    colnames(res.formatted) <- c("POS","REF","ALT","AF","STAT","PVALUE","BETA","SD","N","numStability");
    return(list(res.formatted=res.formatted,
                dat=dat,
                r2=r2,
                marginal.statistic=marginal.statistic,
                marginal.p.value=marginal.p.value,
                raw.data.all=raw.data.all,
                res.cond=res.cond));
}

getCondUV <- function(...) {
    numStability <- 1;
    pars <- list(...);
    ix.candidate <- pars$ix.candidate;
    ix.known <- pars$ix.known;
    dat <- pars$dat;
    lambda <- pars$lambda;
    r2 <- pars$r2;
    if(is.null(lambda)) lambda <- 0.1;
    ustat.meta <- rowSums(dat$ustat.mat,na.rm=TRUE);
    vstat.sq.meta <- rowSums((dat$vstat.mat)^2,na.rm=TRUE);
    nSample.meta <- rowSums(dat$nSample.mat,na.rm=TRUE);
    nSample.meta <- nSample.meta;
    
    V <- 0;
    N.V <- 0;
    for(jj in 1:ncol(dat$ustat.mat)) {
        
        vstat <- (rm.na(dat$vstat.mat[,jj]));
        V.ii <- r2*vstat;
        V <- V+t(V.ii)*vstat;
        N.V <- N.V+rm.na(sqrt(dat$nSample.mat[,jj]))%*%t(rm.na(sqrt(dat$nSample.mat[,jj])))
    }
    covG <- V/N.V;
    covG <- rm.na(covG);
    covG <- regMat(covG,lambda);
    U.meta <- ustat.meta/nSample.meta;
    U.meta <- rm.na(U.meta);
    U.XY <- U.meta[ix.candidate];
    U.ZY <- U.meta[ix.known];
        
    V.XZ <- matrix(covG[ix.candidate,ix.known],nrow=length(ix.candidate),ncol=length(ix.known));
    V.ZZ <- matrix(covG[ix.known,ix.known],nrow=length(ix.known),ncol=length(ix.known));
    V.XX <- matrix(covG[ix.candidate,ix.candidate],nrow=length(ix.candidate),ncol=length(ix.candidate));
    
    conditional.ustat <- U.XY-V.XZ%*%ginv(V.ZZ)%*%U.ZY;
    
    
    beta.ZY <- ginv(V.ZZ)%*%U.ZY;
    scaleMat <- as.matrix(as.numeric(diag(as.matrix(N.V)))%*%t(as.numeric(diag(as.matrix(N.V)))))
    var.U.XY <- rm.na(V[ix.candidate,ix.candidate]/(scaleMat[ix.candidate,ix.candidate]));
    var.U.ZY <- rm.na(V[ix.known,ix.known]/(scaleMat[ix.known,ix.known]))

    cov.U.XY.U.ZY <- rm.na(V[ix.candidate,ix.known]/matrix(scaleMat[ix.candidate,ix.known],nrow=length(ix.candidate),ncol=length(ix.known)));

    conditional.V <- var.U.XY+V.XZ%*%ginv(V.ZZ)%*%var.U.ZY%*%ginv(V.ZZ)%*%t(V.XZ)-cov.U.XY.U.ZY%*%t(V.XZ%*%ginv(V.ZZ))-(V.XZ%*%ginv(V.ZZ))%*%t(cov.U.XY.U.ZY);
    sigma.sq.est <- abs(1-(t(U.ZY)%*%ginv(V.ZZ)%*%U.ZY));
    conditional.V <- conditional.V*as.numeric(sigma.sq.est);
    if(conditional.V<0) numStability <- 0;
    conditional.V <- regMat(conditional.V,lambda);
    conditional.beta.est <- ginv(V.XX-V.XZ%*%ginv(V.ZZ)%*%t(V.XZ))%*%conditional.ustat;
    conditional.beta.var <- ginv(V.XX-V.XZ%*%ginv(V.ZZ)%*%t(V.XZ))%*%conditional.V%*%ginv(V.XX-V.XZ%*%ginv(V.ZZ)%*%t(V.XZ));
    if(length(which(is.na(diag(conditional.V))))>0 || length(which((diag(conditional.V)==0)))>0) {
    }
    return(list(conditional.ustat=conditional.ustat,
                conditional.V=conditional.V,
                numStability=numStability,
                conditional.beta.est=conditional.beta.est,
                conditional.beta.var=conditional.beta.var,
                nSample=nSample.meta));
    
}
regMat <- function(M,lambda) {
        cor.tmp <- rm.na(cov2cor(M));
        sd.mat <- matrix(0,nrow=nrow(M),ncol=ncol(M));
        id.mat <- matrix(0,nrow=nrow(M),ncol=ncol(M));
        diag(id.mat) <- 1;
        diag(sd.mat) <- sqrt(abs(diag(M)));
        cor.tmp <- cor.tmp+lambda*id.mat;
        M.reg <- sd.mat%*%(cor.tmp)%*%sd.mat;
        return(M.reg);
}
