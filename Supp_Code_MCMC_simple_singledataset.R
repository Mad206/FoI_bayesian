#================================================================================================================================#
#============================== Simple cataltyic model fit to single dataset   (Dixon et al. ) ==================================#
#================================================================================================================================# 

#=====================================================#
#                 LIBRARIES                           #

library(dplyr)
library(data.table)
library(ggplot2)
library(MASS) # for covariance matrix


#======================#
#   Load data          #

#SI_data <- read.csv("")  # read in csv 
#View(SI_data)

data <- SI_data[SI_data$Dataset_name == ("Gottschalk et al. 2006"),]

# note code used below for example fitting to Gottschalk et al. (will need modification for other datasets)

#======================#
# Generate p'(a)       #

predicted_prev_func <- function(age, par){
  
  lambda <- par[1]; se<- par[2]; sp <- par[3]
  
  tp <-  1 - exp(-lambda * (data$age_month))   # 'True' (modelled) prevalence - p(a) - as a function of the catalytic model 
  op <- (1-sp) + (se+sp-1)*tp                   # Observed prevalence - p'(a) given by Diggle et al 2011 Epi Res Int
  op
}


#======================#
#  Binomial Likelihood #

# Likelihood Function #
loglike_simple <- function(data, par){
  predicted_seroprevalence = predicted_prev_func(data, par)
  sum(dbinom(data$x, data$n, predicted_seroprevalence, log=T)) # x= positive pigs, n= total pigs
}


#======================#
#        prior         #

prior <- function(par) {
  
  lambda <- par[1]; se<- par[2]; sp <- par[3]
  
  
  lambda_prior = dunif(lambda, min = 0.0001, max = 1, log = T) # uniform prior distribution
  
  se_prior = dbeta(se, 100, 179.2788, log = T)                 # beta prior distribution
  
  sp_prior = dbeta(sp, 77.6, 7.023773, log = T)                # beta prior distribution
   
  return(sum(c(lambda_prior, se_prior, sp_prior)))
  
}

#======================#
#   Posterior          #

posterior_function_simple <- function(data, par){
  loglike_simple(data, par) + prior(par)
}

#======================#
#   Proposal           #

proposal_function_simple <- function(par, cov) {
  
  ## draw propopsals all from a multivariate normal
  repeat {
    proposed <- mvrnorm(1, par, cov)
    if(all(proposed>0 & all(proposed[1:length(par)]<1))){break} 
  }
  
  return(proposed)
  
}  


#======================#
#    MCMC              #

# Run MCMC Function 
MCMC_simple_model <- function(inits,  number_of_iterations, cov) {
  
  # Storage for Output
  MCMC_output <- matrix(nrow = number_of_iterations + 1, ncol=length(inits)) # ncol is number of parameters
  MCMC_output[1,] <- inits
  Acceptances <- vector(length = number_of_iterations + 1)
  LogLikelihood_storage <- vector(length = number_of_iterations + 1)
  Logposterior_storage <- vector(length = number_of_iterations + 1)
  
  
  # Running the Actual MCMC
  for (i in 1:number_of_iterations){
    
    proposed_parameter_value <- proposal_function_simple(MCMC_output[i,], cov)      # new proposed paramater value(s) with a given s.d. (step size)
    
    current_likelihood <- loglike_simple(data, MCMC_output[i,])                     # likelihood 
    
    current_posterior <- posterior_function_simple(data, MCMC_output[i,])           # current posterior from MCMC
    
    proposed_posterior <- posterior_function_simple(data, proposed_parameter_value) # proposed posterior with new proposed par value
    
    likelihood_ratio = exp(proposed_posterior - current_posterior);
    
    if(i %% (number_of_iterations/20) == 0){
      message(round(i/number_of_iterations*100), ' % completed')
    }
    
    if(runif(1) < likelihood_ratio) {
      # likelihood ratio comparison step (exponentiated because on log scale) 
      MCMC_output[i + 1,] <- proposed_parameter_value
      Acceptances[i] <- 1
      LogLikelihood_storage[i + 1] <- current_likelihood
      Logposterior_storage[i + 1] <- proposed_posterior
      
    } else{
      
      MCMC_output[i + 1,] <- MCMC_output[i,]
      Acceptances[i] <- 0
      LogLikelihood_storage[i + 1] <- current_likelihood
      Logposterior_storage[i + 1] <- current_posterior
      
    }
    
  } 
  
  list <- list()
  list[["MCMC_Output"]] <- MCMC_output
  list[["Acceptances"]] <- Acceptances
  list[["Likelihood_Output"]] <- LogLikelihood_storage
  list[["Posterior_Output"]] <- Logposterior_storage
  return(list)
  
}


inits1 <- c(0.2, 0.26, 0.85)   # Initial values for chain 1 (lambda, se, sp)
inits2 <- c(0.001, 0.41, 0.99)

sd <- 0.04                     # standard deviation of proposal distribution 

cov <- diag(sd^2, 3)           # covariance matrix from multivariate proposal distribution 

niter <- 1000000 # number of iterations
burnin <- 100000 # burnin

#=======================#
#      replicate        #

# set.seed() # Uncomment and add seed for determinism in MCMC
#sessionInfo()

#=======================#
#   Run MCMC            #

simple_out_chain1 <- MCMC_simple_model(inits1, niter, cov)  # initiate the MCMC
simple_out_chain2 <- MCMC_simple_model(inits2, niter, cov)  # initiate the MCMC

#==============================#
#     Output                   #

# acceptance ratio (target ~ 0.25)
sum(simple_out_chain1$Acceptances)/niter
sum(simple_out_chain2$Acceptances)/niter


# chains plot 
par(mfrow=(c(1,length(inits1))))
for (i in 1:length(inits1)) {
  if (i==1) {
    ylab="lambda"
  } else if (i==2) {
    ylab="se"
  } else {
    ylab="sp"
  }
  plot(simple_out_chain1$MCMC_Output[,i], type = "l", ylab=ylab, xlab="iter")
  lines(simple_out_chain2$MCMC_Output[,i], col="red")
}

# posterior histogram plots 
par(mfrow=(c(1,length(inits1))))
for (i in 1:length(inits1)) {
  if (i==1) {
    ylab="lambda"
  } else if (i==2) {
    ylab="se"
  } else {
    ylab="sp"
  }
  
  hist(c(simple_out_chain1$MCMC_Output[burnin:niter,i],simple_out_chain2$MCMC_Output[burnin:niter,i]), 
       xlab = ylab, main="")
  
}

#==================#
# autocorrelation  # 

par(mfrow=c(2,3))
acf(tail(simple_out_chain1$MCMC_Output[,1], 9500)) # autocorrelation function (y-axis) ~ lag (x-axis) plot for each parameter/chain
acf(tail(simple_out_chain1$MCMC_Output[,2], 9500)) # want ACF to drop with increasing k (or lag)
acf(tail(simple_out_chain1$MCMC_Output[,3], 9500)) # see tutorial for info: http://sbfnk.github.io/mfiidd/mcmc_diagnostics.html 
acf(tail(simple_out_chain2$MCMC_Output[,1], 9500))
acf(tail(simple_out_chain2$MCMC_Output[,2], 9500))
acf(tail(simple_out_chain2$MCMC_Output[,3], 9500)) 

# calculate  autocorrelation within chains #
autocor.lambda.simple.catalytic.t1 <- cor(simple_out_chain1$MCMC_Output[,1][-1],simple_out_chain1$MCMC_Output[,1][-length(simple_out_chain1$MCMC_Output[,1])]) # autocorrelation for parameter 1, chain 1
autocor.se.simple.catalytic.t1 <- cor(simple_out_chain1$MCMC_Output[,2][-1],simple_out_chain1$MCMC_Output[,2][-length(simple_out_chain1$MCMC_Output[,2])])
autocor.sp.simple.catalytic.t1 <- cor(simple_out_chain1$MCMC_Output[,3][-1],simple_out_chain1$MCMC_Output[,3][-length(simple_out_chain1$MCMC_Output[,3])])

# plot 
par(mfrow=c(3,1))
plot(simple_out_chain1$MCMC_Output[,1][-1],simple_out_chain1$MCMC_Output[,1][-length(simple_out_chain1$MCMC_Output[,1])],main=paste("lambda simple catalytic model (chain 1): autocorrelation =",signif(autocor.lambda.simple.catalytic.t1,3)),xlab="",ylab="")
plot(simple_out_chain1$MCMC_Output[,2][-1],simple_out_chain1$MCMC_Output[,2][-length(simple_out_chain1$MCMC_Output[,2])],main=paste("se simple catalytic model (chain 1) autocorrelation =",signif(autocor.se.simple.catalytic.t1,3)),xlab="",ylab="")
plot(simple_out_chain1$MCMC_Output[,3][-1],simple_out_chain1$MCMC_Output[,3][-length(simple_out_chain1$MCMC_Output[,3])],main=paste("sp simple catalytic model (chain 1) autocorrelation =",signif(autocor.sp.simple.catalytic.t1,3)),xlab="",ylab="")

# output 
signif(autocor.lambda.simple.catalytic.t1,3)
signif(autocor.se.simple.catalytic.t1,3)
signif(autocor.sp.simple.catalytic.t1,3)

#==================#
# correlation      # 

## lambda ~ se ##
par(mfrow=c(1,1))
cor.t1_simple.lamse <- cor(simple_out_chain1$MCMC_Output[, 1],simple_out_chain1$MCMC_Output[, 2])
plot(simple_out_chain1$MCMC_Output[, 1],simple_out_chain1$MCMC_Output[, 2],main=paste("Correlation for lambda ~ se (chain 1, simple model)=",signif(cor.t1_simple.lamse,3)),xlab="lambda",ylab="se")
cor.t1_simple.lamse

## lambda ~ sp ##
cor.t1_simple.lamsp <- cor(simple_out_chain1$MCMC_Output[, 1],simple_out_chain1$MCMC_Output[, 3])
plot(simple_out_chain1$MCMC_Output[, 1],simple_out_chain1$MCMC_Output[, 3],main=paste("Correlation for lambda ~ sp (chain 1, simple model)=",signif(cor.t1_simple.lamsp,3)),xlab="lambda",ylab="sp")
cor.t1_simple.lamsp

## se ~ sp ##
cor.t1_simple.sesp <- cor(simple_out_chain1$MCMC_Output[, 2],simple_out_chain1$MCMC_Output[, 3])
plot(simple_out_chain1$MCMC_Output[, 2],simple_out_chain1$MCMC_Output[, 3],main=paste("Correlation for se ~ sp (chain 1, simple model)=",signif(cor.t1_simple.sesp,3)),xlab="se",ylab="se")
cor.t1_simple.sesp

#======================#
# Processing of chains #

chains1_output <- simple_out_chain1$MCMC_Output
chains2_output <- simple_out_chain2$MCMC_Output

# function to call #
plot_chains<-function(run1, run2){
  par(mfrow=c(ncol(run1),1))
  
  for(i in 1:ncol(run1)){
    plot(run1[,i], t='l', col='deeppink',
         ylim=c(min(c(run1[,i], run2[,i])),max(c(run1[,i], run2[,i]))),
         xlab='', ylab=paste('Parameter', i, sep=' '))
    lines(run2[,i], col='dodgerblue')
  }
  
}

Burn<-function(chains, burnin){
  chains[-(1:burnin),]
}

Downsample<-function(chains, sample){
  chains[seq(1, nrow(chains), sample),]
}

Process_chains<-function(run1, run2, burnin, sample){
  C1<-Burn(run1, burnin)
  C2<-Burn(run2, burnin)
  
  
  C1<-Downsample(C1, sample)
  C2<-Downsample(C2, sample)
  
  
  return(list(C1, C2))
}

# Processing of chains function (# modify burnin and sub-sampling (reduce memory requirement of chains & autocorrelation))
PC_simple <-Process_chains(chains1_output, chains2_output, burnin=100000, sample=10) 
plot_chains(PC_simple[[1]], PC_simple[[2]]) # plot new chains

# replot ACF ~ lag to check autocorrelation after thinning #
par(mfrow=c(2,3))
acf(tail(PC_simple[[1]][,1], 9500)) # autocorrelation function (y-axis) ~ lag (x-axis) plot for each parameter/chain
acf(tail(PC_simple[[1]][,2], 9500)) 
acf(tail(PC_simple[[1]][,3], 9500)) 
acf(tail(PC_simple[[2]][,1], 9500)) 
acf(tail(PC_simple[[2]][,2], 9500)) 
acf(tail(PC_simple[[2]][,3], 9500)) 

autocor.lambda.simple.t1 <- cor(PC_simple[[1]][,1][-1],PC_simple[[1]][,1][-length(PC_simple[[1]][,1])])
autocor.se.simple.t1 <- cor(PC_simple[[1]][,2][-1],PC_simple[[1]][,2][-length(PC_simple[[1]][,2])])
autocor.sp.simple.t1 <- cor(PC_simple[[1]][,3][-1],PC_simple[[1]][,3][-length(PC_simple[[1]][,3])])

signif(autocor.lambda.simple.t1,3)
signif(autocor.se.simple.t1,3)
signif(autocor.sp.simple.t1,3)

#====================================================#
#   Post processing posterior plotting               #

# best parameter point estimates from distributions and credible intervals ##

lambda.simple<-quantile(c(PC_simple[[1]][,1], PC_simple[[2]][,1]), c(0.025,0.5,0.975))
se.simple<-quantile(c(PC_simple[[1]][,2], PC_simple[[2]][,2]), c(0.025,0.5,0.975))
sp.simple<-quantile(c(PC_simple[[1]][,3], PC_simple[[2]][,3]), c(0.025,0.5,0.975))

lambda.simple
se.simple
sp.simple

# only medians
lambda.median<-quantile(c(PC_simple[[1]][,1], PC_simple[[2]][,1]), c(0.5))
se.median<-quantile(c(PC_simple[[1]][,2], PC_simple[[2]][,2]), c(0.5))
sp.median<-quantile(c(PC_simple[[1]][,3], PC_simple[[2]][,3]), c(0.5))

# only credible intervals
lambda.credible<-quantile(c(PC_simple[[1]][,1], PC_simple[[2]][,1]), c(0.025, 0.975))
se.credible<-quantile(c(PC_simple[[1]][,2], PC_simple[[2]][,2]), c(0.025, 0.975))
sp.credible<-quantile(c(PC_simple[[1]][,3], PC_simple[[2]][,3]), c(0.025, 0.975))

# plot posterior distributions #
par(mfrow=c(1,3))
hist(c(PC_simple[[1]][,1], PC_simple[[2]][,1]), breaks=30, xlab='Lambda')    # Parameter 1 - lambda 

hist(c(PC_simple[[1]][,2], PC_simple[[2]][,2]), breaks=30, xlab='sens')      # Parameter 2 - sensitivity 

hist(c(PC_simple[[1]][,3], PC_simple[[2]][,3]), breaks=30, xlab='spec')      # Parameter 2 - specificty 


#===================================================#
#     Predicted prevalence curves                   #

# specify new predicted prev function (for p'(a)) to work in dataframe below
predicted_prev_func2 <- function(age, par){
  
  lambda <- par[1]; se<- par[2]; sp <- par[3]
  
  tp <-  1 - exp(-lambda * (age))  # 'True' (modelled) prevalence - p(a) - as a function of the catalytic model 
  op <- (1-sp) + (se+sp-1)*tp      # Observed prevalence - p'(a) given by Diggle et al 2011 Epi Res Int
  op
}

# Predicted prevalence curve using posterior median point estimates #
age_month <- seq(from=0, to=40, by=0.005)  ## ages to produce predicted prevalence over
fitted_curve_df <- as.data.frame(age_month) 
predicted_simple <- full_join(fitted_curve_df, data) 
predicted_simple$predicted <- sapply(1:nrow(predicted_simple), function(i) predicted_prev_func2(age=predicted_simple$age_month[i], c(lambda.median, se.median, sp.median)))

#================================================================================================================#
# Create uncertainty around point estimates (using credible interval) of model run by subsampling from posterior # 

subsampled_model <- matrix(NA, nrow = length(PC_simple[[1]][,1]), ncol = length(seq(0, 40, 0.005))) # create matrix to store uncertainty output

for (i in 1:length(PC_simple[[1]][,1])){
  
  single_model_output <- predicted_prev_func2(seq(0, 40, 0.005),c(PC_simple[[1]][i,1],PC_simple[[1]][i,2],PC_simple[[1]][i,3]))
  subsampled_model[i, ] <- single_model_output
  
}

lower_credible_interval <- apply(subsampled_model, MARGIN = 2, quantile, prob = 0.025)
upper_credible_interval <- apply(subsampled_model, MARGIN = 2, quantile, prob = 0.975)

Lower_sub <- as.data.frame(lower_credible_interval)
Upper_sub <- as.data.frame(upper_credible_interval)
simple_CrI <- cbind(Lower_sub, Upper_sub)
simple_CrI <- as.data.frame(simple_CrI)
simple_CrI$age_month <- fitted_curve_df$age_month


# plot predicted (using ggplot2) #
ggplot() +   
  theme(legend.position = 'none') +   
  geom_point(data=predicted_simple, aes(x=age_month, y=Observed_prevalence))+
  geom_errorbar(data=predicted_simple,aes(x=age_month, y=Observed_prevalence, ymin=lower, ymax=upper), width=0.8)+
  geom_line(data=predicted_simple,aes(x=age_month, y=predicted), size= 1.1, colour='purple')+
  geom_ribbon(data=simple_CrI,aes(x=age_month, ymin=lower_credible_interval, ymax=upper_credible_interval), fill="purple", alpha=0.1)+
  ylim(0,1.0)


