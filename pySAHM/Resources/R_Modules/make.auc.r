make.auc.plot.jpg<-function(out=out){

  plotname<-paste(out$dat$bname,"_auc_plot.jpg",sep="")
  modelname<-toupper(out$input$model)
  input.list<-out$dat$ma

######################### Calc threshold on train split #################
 if(out$input$model.family!="poisson"){
            thresh <- as.numeric(optimal.thresholds(data.frame(ID=1:nrow(input.list$train$dat),pres.abs=input.list$train$dat[,1],
                pred=input.list$train$pred),opt.methods=out$input$opt.methods))[2]
            }
            else thresh=NULL

################# Calculate all statistics on test\train or train\cv splits
  Stats<-lapply(input.list,calcStat,family=out$input$model.family,thresh=thresh)

########################## PLOTS ################################
  #Residual surface of input data
  residual.smooth.fct<-resid.image(calc.dev(input.list$train$dat$response, input.list$train$pred, input.list$train$weight, family=out$input$model.family)$dev.cont,input.list$train$pred,
          input.list$train$dat$response,input.list$train$XY$X,input.list$train$XY$Y,out$input$model.family,out$input$output.dir)

  train.mask<-seq(1:length(Stats))[names(Stats)=="train"]


    lst<-list()
    if(out$dat$split.type=="test")
      lst$test<-Stats[[-c(train.mask)]]
    if(out$dat$split.type=="crossValidation") lst<-Stats[[-c(train.mask)]]


 #AUC plot for binomial data
    if(out$input$model.family%in%c("binomial","bernoulli")){
            jpeg(file=plotname)
            TestTrainRocPlot(DATA=Stats$train$auc.data,opt.thresholds=thresh,add.legend=(length(Stats)==1),lwd=2)
            if(out$dat$split.type!="none") {
            #so here we have to extract a sublist and apply a function to the sublist but if it has length 2 the structure of the list changes when the sublist is extracted
            lapply(lapply(lst,function(lst){lst$auc.data}),
              TestTrainRocPlot,model.names=modelname,opt.thresholds=thresh,add.roc=TRUE,line.type=2,color="red",add.legend=FALSE)
                legend(x=.66,y=.2,c("Training Split","Testing Split","Cross Validation Sets")[c(1,2*(length(Stats)==2),3*(length(Stats)>2))],lty=2,col=c("black","red"),lwd=2)
                }
            graphics.off()}

    #Some residual plots for poisson data
    if(out$input$model.family%in%c("poisson")){
            jpeg(file=plotname)
            par(mfrow=c(2,2))
             plot(log(Statspred[pred!=0]),(auc.data$pres.abs[pred!=0]-pred[pred!=0]),xlab="Predicted Values (log scale)",ylab="Residuals",main="Residuals vs Fitted",ylim=c(-3,3))
              abline(h=0,lty=2)
              #this is the residual plot from glm but I don't think it will work for anything else
              qqnorm(residuals(out$mods$final.mod),ylab="Std. deviance residuals")
              qqline(residuals(out$mods$final.mod))
               yl <- as.expression(substitute(sqrt(abs(YL)), list(YL = as.name("Std. Deviance Resid"))))
              plot(log(pred[pred!=0]),sqrt((abs(residuals(out$mods$final.mod,type="deviance")[pred!=0]))),xlab="Predicted Values (log Scale)",ylab=yl)
            graphics.off()}

 ##################### CAPTURING TEXT OUTPUT #######################
    capture.output(cat("\n\n============================================================",
                        "\n\nEvaluation Statistics"),file=paste(out$dat$bname,"_output.txt",sep=""),append=TRUE)
      #this is kind of a pain but I have to keep everything in the same list format
      train.stats=list()
     if(out$dat$split.type=="none") train.stats<-Stats
      else train.stats$train=Stats[[train.mask]]

    capture.stats(train.stats,file.name=paste(out$dat$bname,"_output.txt",sep=""),label="train",family=out$input$model.family,opt.methods=out$input$opt.methods,thresh=thresh)
    if(out$dat$split.type!="none"){
    capture.output(cat("\n\n============================================================",
                        "\n\nEvaluation Statistics"),file=paste(out$dat$bname,"_output.txt",sep=""),append=TRUE)
        capture.stats(lst,file.name=paste(out$dat$bname,"_output.txt",sep=""),label=out$dat$split.type,family=out$input$model.family,opt.methods=out$input$opt.methods,thresh=thresh)
    }

        browser()
                       last.dir<-strsplit(out$input$output.dir,split="\\\\")
                        parent<-sub(paste("\\\\",last.dir[[1]][length(last.dir[[1]])],sep=""),"",out$input$output.dir)

                         compile.out<-paste(parent,
                              paste(switch(out$input$model.family,"binomial"="Binary","bernoulli"="Binary","poisson"="Count"),
                                switch(out$dat$split.type,"test"="TestTrain","crossValidation"="CV","none"=""),
                              "AppendedOutput.csv",sep=""),sep="/")

                               lapply(train.stats,function(lst){browser()
                               return(c(lst$correlaiton,lst$pct.dev.exp))})
                              a<-c(train.stats$correlation,train.stats$pct.dev.exp,train.stats$Pcc,train.stats$Sens,train.stats$Specf)
                       if(out$input$model.family%in%c("binomial","bernoulli")){
                       x=data.frame(cbind(c("Correlation Coefficient","Percent Deviance Explained","Percent Correctly Classified","Sensitivity","Specificity"),
                            c(as.vector(cor.test(pred,response)$estimate),pct.dev.exp,PCC,SENS,SPEC)))
                       }else  x=data.frame(cbind(c("Correlation Coefficient","Percent Deviance Explained","Prediction Error"),
                            c(as.vector(cor.test(pred,response)$estimate),pct.dev.exp,prediction.error)))

                        Header<-cbind(c("","Original Field Data","Field Data Template","PARC Output Folder","PARC Template","Covariate Selection Name",""),
                            c(last.dir[[1]][length(last.dir[[1]])],
                            out$dat$ma$input$OrigFieldData,out$dat$ma$input$FieldDataTemp,out$dat$ma$input$ParcOutputFolder,
                            out$dat$ma$input$ParcTemplate,ifelse(length(out$dat$ma$input$CovSelectName)==0,"NONE",out$dat$ma$input$CovSelectName),""))

AppendOut(compile.out,Header,x,out,test.split,parent=parent)

    return(list(thresh=thresh,cmx=cmx,null.dev=null.dev,dev.fit=dev.fit,dev.exp=dev.exp,pct.dev.exp=pct.dev.exp,auc=auc.fit[1,1],auc.sd=auc.fit[1,2],
        plotname=plotname,pcc=PCC,sens=SENS,spec=SPEC,kappa=KAPPA,tss=TSS,correlation=correlation,residual.smooth.fct=residual.smooth.fct))
}

