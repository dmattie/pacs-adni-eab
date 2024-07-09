library(dplyr)
library(tidyr)
library(lme4)
library(mice)
library(VIM)
library(glmnet)
library(caret)
library(recipes)
library(doParallel)
library(xgboost)
library(smotefamily)
library(pROC)
library(PRROC)
library(ggplot2)
library(plotly)
library(earth)
library(yardstick)

args=commandArgs(trailingOnly=TRUE)
if (length(args)==0){
  workingdir<-'~/datacommons/projects/adni3/Q4'
 
} else {
  workingdir<-args[1]
}
output_dir<-workingdir
data<-read.csv(paste0(workingdir,"/data_train_converter.csv"))
data_test<-read.csv(paste0(workingdir,"/data_test_converter.csv"))

data$X<-NULL
data_test$X<-NULL
#::: ADASYN
predictors<-data[,2:ncol(data)]
df2Gen<-ADAS(predictors,data$CONVERTER,K=5)

predictors<-data_test[,2:ncol(data_test)]
df2Gen_test<-ADAS(predictors,data_test$CONVERTER,K=3)

table(df2Gen_test$data$class)

data<-df2Gen$data
data_test<-df2Gen_test$data
data$class<-as.factor(data$class)
data_test$class<-as.factor(data_test$class)
data<-as.data.frame(data)
recipe<-recipe(class~.,data=data)

recipe<-recipe %>%
  step_nzv(all_predictors(),-all_outcomes())%>%
  step_normalize(all_numeric(),-all_outcomes())

prep<-prep(recipe,data)
data<-bake(prep,new_data=data)

MySummary<-function (data, lev=NULL, model=NULL){
  a1<-defaultSummary(data, lev, model)
  out<-c(a1)
  out}

cv<-trainControl(method="repeatedcv",
                 number=10,
                 repeats=5,
                 search="grid",
                 verboseIter=TRUE,
                 classProbs=TRUE,
                 returnResamp="final",
                 savePredictions="final",
                 summaryFunction=MySummary,
                 selectionFunction="tolerance",
                 allowParallel=TRUE)

#:::::::: RF
num_features <- ncol(data) - 1 

hyper_grid_rf <- expand.grid(
  mtry = c(2, floor(sqrt(num_features)), floor(num_features/3))#, nodesize = c(1, 5,7, 10)  # Control for tree complexity
)

set.seed(35)
cv_rf<- train(class ~ ., 
              data = data,
              method = "rf",  # Example: Random Forest
              trControl = cv,
              tuneGrid=hyper_grid_rf,
              metric = "Kappa")

#saveRDS(cv_rf,paste0(workingdir,'/cv_rf.obj'))  
#cv_rf<-readRDS(paste0(workingdir,'/cv_rf.obj'))
probs<-predict(cv_rf,data_test,type="prob")
predictions<-predict(cv_rf,data_test)
confMatrix <- confusionMatrix(as.factor(predictions), as.factor(data_test$class))
print(confMatrix)

#:::: AUROC AUPRC
roc_obj <- roc(data_test$class, probs[, "Converter"])  # Assuming "AD" is the positive class
auroc <- auc(roc_obj)
print(paste("AUROC:", auroc))

# AUPRC

pr_obj <- pr.curve(scores.class0 = probs[, "Converter"], weights.class0 =as.numeric(data_test$class == "Converter"))
auprc <- pr_obj$auc.integral
print(paste("AUPRC:", auprc))

#:::::: RF F1
precision <- confMatrix$byClass['Pos Pred Value']
recall <- confMatrix$byClass['Sensitivity'] 
f1_score<- 2 * (precision * recall) / (precision+recall)
print(paste0("F1: ",f1_score))

#PR curve with plotly
ypred<-predict(cv_rf,
               newdata=data_test,
               type="prob")
yscore<-data.frame(ypred$Converter)

rdb <- cbind(data_test$class,yscore)
colnames(rdb) = c('y','yscore')

#::::::::: ROC
pdb <- roc_curve(rdb, y, yscore)
pdb$specificity <- 1 - pdb$specificity
auc = roc_auc(rdb, y, yscore)
auc = auc$.estimate

tit = paste('ROC Curve (AUC = ',toString(round(auroc,2)),')',sep = '')

figROC <-  plot_ly(data = pdb ,x =  ~specificity, y = ~sensitivity, type = 'scatter', mode = 'lines', fill = 'tozeroy') %>%
  layout(title = tit,xaxis = list(title = "False Positive Rate"), yaxis = list(title = "True Positive Rate")) %>%
  add_segments(x = 0, xend = 1, y = 0, yend = 1, line = list(dash = "dash", color = 'black'),inherit = FALSE, showlegend = FALSE)

#::::::::: PR

pdb <- pr_curve(rdb, y, yscore)
auc = roc_auc(rdb, y, yscore)
auc = auc$.estimate

tit = paste('PR Curve (AUC = ',toString(round(auprc,2)),')',sep = '')
figPR <-  plot_ly(data = pdb ,x =  ~recall, y = ~precision, type = 'scatter', mode = 'lines', fill = 'tozeroy') %>%
  add_segments(x = 0, xend = 1, y = 0.5, yend = 0.5, line = list(dash = "dash", color = 'black'),inherit = FALSE, showlegend = FALSE) %>%
  layout(title = tit, xaxis = list(title = "Recall"), yaxis = list(title = "Precision") )

# Combine plots with subplot function
ABfig<-subplot(figROC,figPR, nrows = 1, shareX = TRUE, titleX = TRUE,
               margin = 0.05, titleY = TRUE, which_layout = "merge") %>%
  layout(title = paste("AUROC =",toString(round(auroc,2)),
                       " AUPRC =",toString(round(auprc,2))
  ), showlegend = FALSE, 
  xaxis = list(domain = c(0, 0.45)),  # Adjust domain for non-overlapping
  xaxis2 = list(domain = c(0.55, 1))) # Adjust domain for non-overlapping

png(file = paste0(output_dir,"Q4_RF_AUROC_AUPRC.png"),  
    width = 8, 
    height = 3.5) 

print(ABfig)


dev.off()

