CrossValidationSplit<-function(input.file,output.file,response.col="ResponseBinary",n.folds=10,stratify=FALSE,seed){

#Description:
#this code takes as input an mds file with the first line being the predictor or
#response name, the second line an indicator of predictors to include and the
#third line being paths where tif files can be found.   An output file and a
#response column must also be specified.  Given a number of folds, a new
#column is created indicating which fold each observation will be assigned to
#if a Split Column is also found (test/train split) then only the train portion
#will be assigned a fold.  Optional stratification by response is also available
#Background points are ignored
#by this module (they are read in, written out, but not assigned to cv folds.
#Output is written to a csv that can be used by the
#SAHM R modules.

#Written by Marian Talbert 9/29/2011
 if(is.null(seed)) seed<-round(runif(1,min=-((2^32)/2-1),max=((2^32)/2-1)))
set.seed(as.numeric(seed))
options(warn=1)
     if(n.folds<=1 | n.folds%%1!=0) stop("n.folds must be an integer greater than 1")

   #Read input data and remove any columns to be excluded
          dat.in<-read.csv(input.file,header=FALSE,as.is=TRUE)
          dat<-as.data.frame(dat.in[4:dim(dat.in)[1],])
   # if there was a test training split this should be used for Evaluation of the final model since cross validation can only be
   # used for model selection
          if(any(!is.na(match("Split",dat.in[1,])))) dat.in[1,match("Split",dat.in[1,])]<-"EvalSplit"
          names(dat)<-dat.in[1,]

        response<-dat[,match(tolower(response.col),tolower(names(dat)))]
           if(any(response==-9998)) {
           response[response==-9998]<-0
           }
           
          if(sum(as.numeric(response)==0)==0 && !is.null(stratify)) stop("The ratio of presence to absence cannot be set with only presence data")

      #Ignoring background data that might be present in the mds

          bg.dat<-dat[response==-9999,]
          if(dim(bg.dat)[1]!=0){
            dat<-dat[-c(which(response==-9999,arr.ind=TRUE)),]
            dat.in<-dat.in[-c(which(response==-9999,arr.ind=TRUE)+3),]
            response<-response[-c(which(response==-9999,arr.ind=TRUE))]
            bg.dat$Split=""
            }


        # tagging factors and looking at their levels warning users if their factors have few levels
         factor.cols <- grep("categorical",names(dat))
         if(length(factor.cols)!=0){
           for (i in 1:length(factor.cols)){
               factor.table<-table(dat[,factor.cols[i]])
                 if(any(factor.table<10)) {warning(paste("Some levels for the categorical predictor ",names(dat)[factor.cols[i]]," do not have at least 10 observations.\n",
                                                                   "you might want to consider removing or reclassifying this predictor before continuing.\n",
                                                                   "Factors with few observations can cause failure in model fitting when the data is split and cannot be reilably used in training a model.",sep=""))
                    factor.table<-as.data.frame(factor.table)
                     colnames(factor.table)<-c("Factor Name","Factor Count")
                     cat(paste("\n",names(dat)[factor.cols[i]],"\n"))
                     print(factor.table)
                     cat("\n\n")
                   }
              }
            }
            #this splits the training set
              if(any(!is.na(match(tolower("evalsplit"),tolower(names(dat)))))){
             split.mask<-dat[,match(tolower("evalsplit"),tolower(names(dat)))]=="train"
             index<-seq(1:nrow(dat))[split.mask]
             } else split.mask<-index<-seq(1:nrow(dat))
             if(stratify==TRUE){
               dat[,ncol(dat)+1]<-NA
                for(i in 1:length(names(table(response)))){
                  index.i<-index[response[split.mask]==names(table(response))[i]]
                  index.i<-index.i[order(runif(length(index.i)))]
                  dat[index.i,ncol(dat)]<-c(rep(seq(1:n.folds),each=floor(length(index.i)/n.folds)),sample(seq(1:n.folds),size=length(index.i)%%n.folds,replace=FALSE))
                }
             } else{
                index<-index[order(runif(length(index)))]
                dat[index,ncol(dat)+1]<-c(rep(seq(1:n.folds),each=floor(length(index)/n.folds)),sample(seq(1:n.folds),size=length(index)%%n.folds,replace=FALSE))
             }
             names(dat)[ncol(dat)]<-"Split"
         #inserting data must be done in 3 steps because dat.in isn't a proper dataframe in that
         #not all elements in a column are of the same type

          dat.in<-dat.in[c(1:3,rownames(dat)),] #removing rows that weren't selected for the test train split
          dat.in[4:(dim(dat.in)[1]),(dim(dat.in)[2]+1)]<-dat$Split
          dat.in[c(1,3),(dim(dat.in)[2])]<-c("Split","")
          dat.in[2,(dim(dat.in)[2])]<-1

              if(dim(bg.dat)[1]!=0) {
                names(bg.dat)<-names(dat.in)
                dat.in<-rbind(dat.in,bg.dat)}

              #write output files for R modules
             write.table(dat.in,file=output.file,row.names=FALSE,col.names=FALSE,sep=",",quote=FALSE)


    }

  #assign default values
  responseCol="ResponseBinary"
  n.folds=10
  stratify=TRUE
  seed=NULL
 #Reading in command line arguments
 Args <- commandArgs(T)
    print(Args)

    #replace the defaults with passed values
    for (arg in Args) {
    	argSplit <- strsplit(arg, "=")
    	argSplit[[1]][1]
    	argSplit[[1]][2]
    	if(argSplit[[1]][1]=="nf") n.folds <- argSplit[[1]][2]
    	if(argSplit[[1]][1]=="stra") stratify <- argSplit[[1]][2]
    	if(argSplit[[1]][1]=="o") output.file <- argSplit[[1]][2]
    	if(argSplit[[1]][1]=="i") infil <- argSplit[[1]][2]
    	if(argSplit[[1]][1]=="rc") responseCol <- argSplit[[1]][2]
   		if(argSplit[[1]][1]=="seed")  seed <- argSplit[[1]][2]
    }
 stratify<-as.logical(stratify)
 n.folds<-as.numeric(n.folds)
	#Run the Test training split with these parameters
	CrossValidationSplit(input.file=infil,output.file=output.file,response.col=responseCol,
  n.folds=n.folds,stratify=stratify,seed=seed)
