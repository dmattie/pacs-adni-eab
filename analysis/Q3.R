library(dplyr)
library(ggplot2)
library(car)
library(lme4)
library(lmerTest)
# define workingdir
workingdir<-'~/datacommons/projects/adni3/Q4'

df_adc<-read.csv(paste0(workingdir,'/adc/all_adc.csv'),header=FALSE)
colnames(df_adc)<-c('pipeline','participant_id','session_id','seed','target','method','metric','value')
df_vv<-read.csv(paste0(workingdir,'/voxelvolume/all-voxel-volumes.csv'),header=FALSE)
colnames(df_vv)<-c('pipeline','participant_id','session_id','seed','target','method','metric','value')
df_fa<-read.csv(paste0(workingdir,'/fa/all_fa2.csv'),header=FALSE)
colnames(df_fa)<-c('pipeline','participant_id','session_id','seed','target','method','metric','value')
df_len<-read.csv(paste0(workingdir,'/len/all_len2.csv'),header=FALSE)
colnames(df_len)<-c('pipeline','participant_id','session_id','seed','target','method','metric','value')

df_vv<-df_vv[!df_vv$value=="None",]
df_vv$pipeline<-NULL
df_adc$pipeline<-NULL
df_fa$pipeline<-NULL
df_len$pipeline<-NULL

df_vv<-df_vv[df_vv$method=='roi',]
df_adc<-df_adc[df_adc$method=='roi',]
df_fa<-df_fa[df_fa$method=='roi',]
df_len<-df_len[df_len$method=='roi',]
df_vv$method<-NULL
df_adc$method<-NULL
df_fa$method<-NULL
df_len$method<-NULL

names(df_vv)[6]<-"voxelvolume"
df_vv$metric<-NULL       
df_vv$voxelvolume<-as.numeric(df_vv$voxelvolume)
names(df_adc)[6]<-"meanADC"
df_adc$metric<-NULL
names(df_fa)[6]<-"meanFA"
df_fa$metric<-NULL
names(df_len)[6]<-"MeanTractLen"
df_len$metric<-NULL


df<-df_vv %>%
  inner_join(df_adc,by=c("participant_id","session_id","seed","target"))
df_vv<-NULL
df_adc<-NULL
df<-df %>%
  inner_join(df_fa,by=c("participant_id","session_id","seed","target"))

df<-df %>%
  inner_join(df_len,by=c("participant_id","session_id","seed","target"))

participants<-read.csv(paste0(workingdir,"/phenotypic.csv"))#"~/datacommons/projects/adni3/dataframes/participants.csv")
P<-participants[,c("participant_id","viscode2","sex","age","diagnosis")]
names(P)[2]<-"session_id"

df<-df %>%
  inner_join(P,by=c("participant_id","session_id"))

#::::::::: work with DF
df_aggregated<-df %>%
  group_by(seed,diagnosis) %>%
  summarise(
    avg_voxelvolume=mean(voxelvolume,na.rm=TRUE),
    avg_adc=mean(meanADC,na.rm=TRUE),
    avg_fa=mean(meanFA,na.rm=TRUE),
    avg_age=mean(age,na.rm=TRUE)
  ) %>%
  ungroup()
df_aggregated<-subset(df_aggregated,!diagnosis=="")

#::: Normality check

ggplot(df_aggregated %>% filter(seed == 1024), aes(sample = avg_voxelvolume)) +
  geom_qq() +
  geom_qq_line() +
  ggtitle("Q-Q Plot for avg_voxelvolume for roi_seed 1024")

# Shapiro-Wilk normality test
shapiro.test(df_aggregated$avg_voxelvolume[df_aggregated$seed == 1024])

 #Want W=0, p>0.05 -- looks good. repeat for all ROIs

#Homogeneityof variances
df_aggregated$diagnosis<-as.factor(df_aggregated$diagnosis)
df$diagnosis<-as.factor(df$diagnosis)
leveneTest(voxelvolume ~ diagnosis, data = df[df$seed == 1024,], center = mean)


#LMER

df_nona<-subset(df,diagnosis!="")
df_nona$diagnosis<-factor(df_nona$diagnosis,levels=c("CN","MCI","AD"))

# Model for voxelvolume
model_voxelvolume <- lmer(voxelvolume ~ diagnosis + age + (1|participant_id), data = df_nona)
summary(model_voxelvolume)
#FDR Correction for p-val:
p_values<-summary(model_voxelvolume)$coefficients[,"Pr(>|t|)"]
fdr_corrected_p_values <- p.adjust(p_values, method = "fdr")
print(fdr_corrected_p_values)

model_adc <- lmer(meanADC ~ diagnosis + age + (1|participant_id), data = df_nona)
summary(model_adc)
#FDR Correction for p-val:
p_values<-summary(model_adc)$coefficients[,"Pr(>|t|)"]
fdr_corrected_p_values <- p.adjust(p_values, method = "fdr")
print(fdr_corrected_p_values)

model_fa <- lmer(meanFA ~ diagnosis + age + (1|participant_id), data = df_nona)
summary(model_fa)
#FDR Correction for p-val:
p_values<-summary(model_fa)$coefficients[,"Pr(>|t|)"]
fdr_corrected_p_values <- p.adjust(p_values, method = "fdr")
print(fdr_corrected_p_values)

model_len <- lmer(MeanTractLen ~ diagnosis + age + (1|participant_id), data = df_nona)
summary(model_len)
#FDR Correction for p-val:
p_values<-summary(model_len)$coefficients[,"Pr(>|t|)"]
fdr_corrected_p_values <- p.adjust(p_values, method = "fdr")
print(fdr_corrected_p_values)
