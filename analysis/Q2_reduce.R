library(caret)
library(mice)
library(recipes)
library(feather)
library(glmnet)
library(VIM)

#Feature reduction using elasticnet.  This code takes for input the full dataframe
#then partitions the data 80/20 into train/test
#performs feature reduction on the train data
#imputes missing values for the columns that survived
#Writes to CSV files for future ML

args=commandArgs(trailingOnly=TRUE)
if (length(args)==0){
  #dev data
  datafile<-'~/datacommons/projects/adni3/dataframes/adni3.wide.highvar.feather'
  feature<-'adas13'#cdr_sb'
  output<-'~/datacommons/projects/adni3/dataframes/'
  elasticnet_alpha<-0.8
  print(paste("Using default datafile",datafile))
} else {
  datafile<-args[1]
  feature<-args[2] 
  output<-args[3]
  elasticnet_alpha<-as.numeric(args[4])
}


bigdata<-read_feather(datafile)
zz<-as.data.frame(bigdata[,feature])
missing_y <- is.na(zz[[feature]])
zz<-bigdata[!missing_y,]

partition <- createDataPartition(zz[[feature]], p = 0.8, list = FALSE)
train <- zz[partition, ]
test <- zz[-partition, ]

#:::::::::::::: To ensure participant data doesn't leak across from train to test
#               move randomly if participant sessions occur in both
common_participant_ids <- intersect(unique(train$participant_id), unique(test$participant_id))
# If common participant_ids found, move some participants from test to train
cnt<-1
print("shifting participant sessions test/train to avoid leackage.  A participant should not be found in both test and train")
while (length(common_participant_ids) > 0) {
  # Identify a common participant_id
  common_participant_id <- sample(common_participant_ids, 1)
  
  if (sample(c(TRUE, FALSE), 1)==TRUE) {
    # Move rows with the common participant_id from test to train
    moved_rows <- test[test$participant_id == common_participant_id, ]
    train <- rbind(train, moved_rows)
    test <- test[!(test$participant_id == common_participant_id), ]
  } else {
    # Move rows with the common participant_id from train to test
    moved_rows <- train[train$participant_id == common_participant_id, ]
    test <- rbind(test, moved_rows)
    train <- train[!(train$participant_id == common_participant_id), ]
  }
  
  # Update common participant_ids
  common_participant_ids <- intersect(unique(train$participant_id), unique(test$participant_id))
  print(paste("loop count:",cnt," train size:",nrow(train)," test size:",nrow(test)," intersecting:",length(common_participant_ids)))
  cnt<-cnt+1
}

#:::::::::::: Identify response

response<-train[,feature]
response_test<-test[,feature]
feature_min<-min(response[[1]],na.rm=TRUE)
feature_max<-max(response[[1]],na.rm=TRUE)
feature_mean<-mean(response[[1]],na.rm=TRUE)
feature_sd<-sd(response[[1]],na.rm=TRUE)

feature_min_test<-min(response_test[[1]],na.rm=TRUE)
feature_max_test<-max(response_test[[1]],na.rm=TRUE)
feature_mean_test<-mean(response_test[[1]],na.rm=TRUE)
feature_sd_test<-sd(response_test[[1]],na.rm=TRUE)


#:::::::::::: Identify explanatory variables,x1,xn
#             Remove unimportant features. eg ventricles

non_diffusion_cols<-c("participant_id",
                      "session_id",
                      "a_stat",
                      "tau_stat",
                      "diagnosis",
                      "age",
                      "adni_fdg",
                      "adni_av45",
                      "cdr_sb",
                      "adas11",
                      "adas13",
                      "MMSE",
                      "FAQ",
                      "adni_ventricles_vol",
                      "adni_hippocampus_vol",
                      "adni_brain_vol",
                      "adni_entorhinal_vol",
                      "adni_icv",
                      "moca",
                      "adni_fusiform_vol",
                      "adni_midtemp_vol",
                      "ravlt_immediate",
                      "adni_pib",
                      "adas_memory",
                      "adas_language",
                      "adas_concentration",
                      "adas_praxis",
                      "adni_abeta",
                      "adni_tau",
                      "adni_ptau")

ventricles<-names(train)[grep("0004|0005|0014|0015|0028|0031|0043|0044|0060|0063",names(train))]
to_exclude<-append(ventricles,non_diffusion_cols)
predictors <- train[, -which(names(train) %in% to_exclude)]


#.   If data has duplicate column names (suffixed with .<int>).  Remove these
cols_to_remove <- grepl('\\.[0-9]+$', colnames(predictors))
predictors <- predictors[, !cols_to_remove]

#:::::::::: Convert to numeric if read as char
for (i in 1:ncol(predictors)) {
  if (is.character(predictors[[i]])) {
    predictors[[i]] <- as.numeric(predictors[[i]])
    if (i %% 1000 == 0){print(i)}
  }
}
#predictors_full_bak<-predictors
#::::::::::: Remove near zero variance
nzv <- nearZeroVar(predictors, saveMetrics= TRUE)
predictors <- predictors[, !nzv$nzv]

#:::::::::: Use mean imputation to perform Lasso.  We tried mice and others but failed to achieve it
predictors <- data.frame(lapply(predictors, function(x) {
  if(is.numeric(x)) {
    x[is.na(x)] <- mean(x, na.rm = TRUE)
  }
  return(x)
}))
print(paste0("Predict cols - all numeric:",ncol(predictors)))
#::::::::::: Normalize predictors
normalize_minmax <- function(x) {
  range <- max(x, na.rm = TRUE) - min(x, na.rm = TRUE)
  if(range == 0 ) {
    return(rep(NA, length(x)))
  } else {
    # Normalize non-NA values only
    return ((x - min(x, na.rm = TRUE)) / range)
  }
}

predictors <- apply(predictors, MARGIN = 2, FUN = normalize_minmax)

#::::::::::: Lasso regression to eliminate features
predictors<-as.matrix(predictors)

print(paste("Predictors rows:",nrow(predictors)," cols:",ncol(predictors)))

response<-response[[feature]]
glmnet_model <- glmnet(x = predictors, y = response, alpha = elasticnet_alpha)  # alpha = 1 for lasso regularization
cv_model<-cv.glmnet(x=predictors,y=response,alpha=elasticnet_alpha,nfolds=5)

optimal_lambda<-cv_model$lambda.min
coefficients <- coef(glmnet_model, s = optimal_lambda)
significant_features <- which(coefficients[-1] != 0)
significant_feature_names<-colnames(predictors)[significant_features]

to_keep<-append(c("participant_id","session_id","diagnosis",feature),significant_feature_names)
df_train<-train[,which(colnames(train) %in% to_keep)]
df_test<-test[,which(colnames(test) %in% to_keep)]

#:::::::::::: DF contains all important features without imputation
#             Lets perform imputation on explanatory variables 
predictors_train<-df_train[,4:ncol(df_train)]
predictors_test<-df_test[,4:ncol(df_test)]
print(paste0("Predictor width after elasticnet ",elasticnet_alpha," ncol:",ncol(predictors_train)))


# Re-convert to numeric
allnull=c()
for (i in 1:ncol(predictors_train)) {
 # print(i)
  if (is.character(predictors_train[[i]])) {
   # print('cnvert train')
    predictors_train[[i]] <- as.numeric(predictors_train[[i]])
    if (i %% 1000 == 0){print(i)}
  }
  if (is.character(predictors_test[[i]])) {
  #  print('cnvert')
    predictors_test[[i]] <- as.numeric(predictors_test[[i]])
    if (i %% 1000 == 0){print(i)}
  }

  if (all(is.na(predictors_test[[i]])) || all(is.na(predictors_train[[i]]))){
  #  print(paste("found",i))
    allnull<-append(allnull,i)
  }
  
  if ( nearZeroVar(predictors_test[[i]], saveMetrics= TRUE)$nzv==TRUE){
    allnull<-append(allnull,i)
  }
  
}

if (length(allnull)>0) {
  predictors_test<-predictors_test[,-allnull]
  predictors_train<-predictors_train[,-allnull]
}

#:::::::::::: Impute KNN
predictors_train<-scale(predictors_train)
predictors_test<-scale(predictors_test)
predictors_train<-as.data.frame(predictors_train)
predictors_test<-as.data.frame(predictors_test)
predictors_train_nona<-predictors_train
predictors_test_nona<-predictors_test

predictors_train_knn<-kNN(predictors_train,k=5) #Impute missing values in features
predictors_test_knn<-kNN(predictors_test,k=5) #Impute missing values in features

predictors_train_knn <- predictors_train_knn[, !sapply(predictors_train_knn, is.logical),drop=FALSE]
predictors_test_knn <- predictors_test_knn[, !sapply(predictors_test_knn, is.logical),drop=FALSE]

write.csv(predictors_train,paste0(output,'/',feature,'_elasticnet.',elasticnet_alpha,'.','train.csv'))
write.csv(predictors_train_knn,paste0(output,'/',feature,'_elasticnet.',elasticnet_alpha,'.','train_nona.csv'))
write.csv(predictors_test_knn,paste0(output,'/',feature,'_elasticnet.',elasticnet_alpha,'.','test_nona.csv'))
write.csv(predictors_test,paste0(output,'/',feature,'_elasticnet.',elasticnet_alpha,'.','test.csv'))

response_detail<--data.frame(train_min=feature_min,
                             train_max=feature_max,
                             train_mean=feature_mean,
                             train_sd=feature_sd,
                             test_min=feature_min_test,
                             test_max=feature_max_test,
                             test_mean=feature_mean_test,
                             test_sd=feature_sd_test)

write.csv(response_detail,paste0(output,'/',feature,'_elasticnet.',elasticnet_alpha,'.','response_detail.csv'))
