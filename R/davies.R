davies.vec <- function(q,lambda,h = rep(1,length(lambda)),delta = rep(0,length(lambda)),sigma=0,lim=10000,acc=0.0001)
  {
    r <- length(lambda)
    if (length(h) != r) stop("lambda and h should have the same length!")
    if (length(delta) != r) stop("lambda and delta should have the same length!")
    
    out <- .C("qfc1",
              lb1=as.double(lambda),
              nc1=as.double(delta),
              n1=as.integer(h),
              r1=as.integer(r),
              sigma=as.double(sigma),
              c1=as.double(q),
              lim1=as.integer(lim),
              acc=as.double(acc),
              trace=as.double(rep(0,7)),
              ifault=as.integer(0),
              res=as.double(rep(0,length(q))),
              ql=as.integer(length(q)))
    
    out$res <- 1 - out$res    
    return(list(trace=out$trace,ifault=out$ifault,Qq=out$res))
    
  }
