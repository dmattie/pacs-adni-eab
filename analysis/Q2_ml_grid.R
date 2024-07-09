library(caret)
library(recipes)
library(doParallel)
library(MLmetrics)
library(RSNNS)


args=commandArgs(trailingOnly=TRUE)
if (length(args)==0){
  workingdir<-'~/datacommons/projects/adni3/dataframes/Q2Reviewer/ravlt/'
  cores_proc=6
  feature<-'ravlt_immediate'
  palpha<-'0.8'
} else {
  workingdir<-args[1]
  cores_proc<-args[2]
  feature<-args[3]
  palpha<-args[4]
  
}
eval<-data.frame(biomarker=character(),
                 alpha=numeric(),
                 model=character(),
                 rmse=numeric(),
                 mae=numeric(),
                 rqs=numeric())

registerDoParallel(cores=cores_proc)

train<-read.csv(paste0(workingdir,'/',feature,'_elasticnet.',palpha,'.train_nona.csv'))
train$X<-NULL
test<-read.csv(paste0(workingdir,'/',feature,'_elasticnet.',palpha,'.test_nona.csv'))
test$X<-NULL
unscale<-read.csv(paste0(workingdir,'/',feature,'_elasticnet.',palpha,'.response_detail.csv'))
#:::::::::::::: RFE

control <- rfeControl(functions = rfFuncs, method = "cv", number = 10)

MySummary<-function (data, lev=NULL, model=NULL){
  a1<-defaultSummary(data, lev, model)
  out<-c(a1)
  out}

# ::::::: CV and hypergrid search
cv<-trainControl (method="repeatedcv",
                  number=10,
                  repeats=10,
                  search="grid",
                  verboseIter=TRUE,
                  classProbs=FALSE,
                  returnResamp="final",
                  savePredictions="final",
                  summaryFunction=MySummary,
                  selectionFunction="tolerance",
                  allowParallel=TRUE)


train_pp<-cbind(train[[feature]],train[,-which(colnames(train) %in% c(feature))])
names(train_pp)[1]<-feature

test_pp<-cbind(test[[feature]],test[,-which(colnames(test) %in% c(feature))])
names(test_pp)[1]<-feature

formula <- as.formula(paste(feature," ~ ."))

#:::::::::::::::::::::::::::::::::: LM :::::::::::::::::::::::::::::::::::::::::
print('::::::::::::::::::::::::::::  LM')
set.seed(7)
cv_lm<-caret::train(formula,
                    data=train,
                    method="lm",
                    metric="RMSE",
                    maximize=FALSE,
                    tuneLength=10,
                    trControl=cv)
saveRDS(cv_lm, file = paste0(workingdir,"/",feature,"_",palpha,"_cv_lm_model.rds"))


predictions <- predict(cv_lm, newdata = test_pp)


rmse <- RMSE(predictions, test_pp[[feature]])*unscale$train_sd*-1
mae <- MAE(predictions, test_pp[[feature]])*unscale$train_sd*-1
rsq <- R2(predictions, test_pp[[feature]])

# Print the evaluation metrics
cat(feature,",lm,",palpha,", RMSE:", rmse, "MAE:", mae, "R-squared:", rsq, "\n")
row<-cbind(biomarker=feature,alpha=palpha,model="lm",rmse=rmse,mae=mae,rsq=rsq)
eval<-rbind(eval,row)
#::::::::::::::::::::::::::::  SVM  ::::::::::::::::::::::::::::::::::::::::::::
print('::::::::::::::::::::::::::::  SVM')
hyper_grid_svm <- expand.grid(
  C = 2^(-5:2), 
  sigma = 2^(-15:3) 
)
cv_svm <- caret::train(
  formula,
  data = train_pp,
  method = "svmRadial",
  metric = "RMSE",
  trControl = cv,
  tuneGrid = hyper_grid_svm
)

saveRDS(cv_svm, file = paste0(workingdir,"/",feature,"_",palpha,"_cv_svm_model.rds"))

predictions <- predict(cv_svm, newdata = test_pp)
rmse <- RMSE(predictions, test_pp[[feature]])*unscale$train_sd*-1
mae <- MAE(predictions, test_pp[[feature]])*unscale$train_sd*-1
rsq <- R2(predictions, test_pp[[feature]])
# Print the evaluation metrics
cat(feature,",svm,",palpha,", RMSE:", rmse, "MAE:", mae, "R-squared:", rsq, "\n")
row<-cbind(biomarker=feature,alpha=palpha,model="svm",rmse=rmse,mae=mae,rsq=rsq)
eval<-rbind(eval,row)
#::::::::::::::::::::::::::::  RF  ::::::::::::::::::::::::::::::::::::::::::::
print('::::::::::::::::::::::::::::  RF')
### Random Forest
hyper_grid_rf <- expand.grid(
  mtry = seq(2, ncol(train_pp) - 1, by = 2)
)

cv_model <- caret::train(
  formula,
  data = train_pp,
  method = "rf",
  metric = "RMSE",
  trControl = cv,
  tuneGrid = hyper_grid_rf,
  ntree = 500
)

saveRDS(cv_model, file = paste0(workingdir,"/",feature,"_",palpha,"_cv_rf_model.rds"))

predictions <- predict(cv_model, newdata = test_pp)
rmse <- RMSE(predictions, test_pp[[feature]])*unscale$train_sd*-1
mae <- MAE(predictions, test_pp[[feature]])*unscale$train_sd*-1
rsq <- R2(predictions, test_pp[[feature]])
# Print the evaluation metrics
cat(feature,",rf,",palpha,", RMSE:", rmse, "MAE:", mae, "R-squared:", rsq, "\n")
row<-cbind(biomarker=feature,alpha=palpha,model="rf",rmse=rmse,mae=mae,rsq=rsq)
eval<-rbind(eval,row)

#::::::::::::::::::::::::::::  DT  ::::::::::::::::::::::::::::::::::::::::::::
### Decision Trees
print('::::::::::::::::::::::::::::  DT')
hyper_grid_dt <- expand.grid(
  cp = seq(0.001, 0.1, by = 0.01)
)

cv_model <- caret::train(
  formula,
  data = train_pp,
  method = "rpart",
  metric = "RMSE",
  trControl = cv,
  tuneGrid = hyper_grid_dt
)
saveRDS(cv_model, file = paste0(workingdir,"/",feature,"_",palpha,"_cv_dt_model.rds"))

predictions <- predict(cv_model, newdata = test_pp)
rmse <- RMSE(predictions, test_pp[[feature]])*unscale$train_sd*-1
mae <- MAE(predictions, test_pp[[feature]])*unscale$train_sd*-1
rsq <- R2(predictions, test_pp[[feature]])
# Print the evaluation metrics
cat(feature,",dt,",palpha,", RMSE:", rmse, "MAE:", mae, "R-squared:", rsq, "\n")
row<-cbind(biomarker=feature,alpha=palpha,model="dt",rmse=rmse,mae=mae,rsq=rsq)
eval<-rbind(eval,row)

#::::::::::::::::::::::::::::  MLP  ::::::::::::::::::::::::::::::::::::::::::::
### MLP
print('::::::::::::::::::::::::::::  MLP')
hyper_grid_mlp <- expand.grid(
  size = seq(1, 10, by = 1),
  decay = seq(0, 0.1, by = 0.01)
)

cv_model <- caret::train(
  formula,
  data = train_pp,
  method = "mlp",
  metric = "RMSE",
  trControl = cv,
  #tuneGrid = hyper_grid_mlp,
  linout = TRUE,
  trace = FALSE,
  maxit = 200
)
saveRDS(cv_model, file = paste0(workingdir,"/",feature,"_",palpha,"_cv_mlp_model.rds"))

predictions <- predict(cv_model, newdata = test_pp)
rmse <- RMSE(predictions, test_pp[[feature]])*unscale$train_sd*-1
mae <- MAE(predictions, test_pp[[feature]])*unscale$train_sd*-1
rsq <- R2(predictions, test_pp[[feature]])
# Print the evaluation metrics
cat(feature,",mlp,",palpha,", RMSE:", rmse, "MAE:", mae, "R-squared:", rsq, "\n")
row<-cbind(biomarker=feature,alpha=palpha,model="mlp",rmse=rmse,mae=mae,rsq=rsq)
eval<-rbind(eval,row)
#::::::::::::::::::::::::::::  XGB  ::::::::::::::::::::::::::::::::::::::::::::
print('::::::::::::::::::::::::::::  XGB')
#Hypergrid for XGBoost

hyper_grid_xgboost<-expand.grid(
  nrounds=seq(from=25, to=100, by=25),
  max_depth=seq(from=5, to=35, by=10),
  eta=seq(from=0.01, to=0.3, by=0.05),
  gamma=seq(from=1, to=10, by=1),
  colsample_bytree=seq(from=0.6, to=1, by=0.2),
  min_child_weight=seq(from=2, to=5, by=1),
  subsample=1)

cv_xgboost<-caret::train(formula,
  data=train_pp,
  method="xgbTree",
  metric="RMSE",
  trControl=cv,
  tuneGrid=hyper_grid_xgboost)

saveRDS(cv_xgboost, file = paste0(workingdir,"/",feature,"_",palpha,"_cv_xgboost_model.rds"))

#data=preprocessed_data[,c(results$optVariables,"diagnosis")],

predictions <- predict(cv_xgboost, newdata = test_pp)


rmse <- RMSE(predictions, test_pp[[feature]])*unscale$train_sd*-1
mae <- MAE(predictions, test_pp[[feature]])*unscale$train_sd*-1
rsq <- R2(predictions, test_pp[[feature]])

# Print the evaluation metrics
cat(feature,",xgbTree,",palpha,", RMSE:", rmse, "MAE:", mae, "R-squared:", rsq, "\n")
row<-cbind(biomarker=feature,alpha=palpha,model="xgb",rmse=rmse,mae=mae,rsq=rsq)
eval<-rbind(eval,row)

write.csv(eval,paste0(workingdir,'/eval_',feature,palpha,'.csv'),row.names=FALSE)