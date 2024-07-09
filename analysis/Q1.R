library(ggplot2)
library(dplyr)
library(gridExtra)
library(grid)
library(patchwork)
library(feather)

args=commandArgs(trailingOnly=TRUE)
if (length(args)==0){
  #Dev data
  datafile<-'~/datacommons/projects/adni3/dataframes/adni3.wide.highvar.feather'
  print(paste("Using default datafile",datafile))
} else {
  datafile<-args[1]
}

bigdata<-read_feather(datafile)

eval<-data.frame(biomarker=character(),
                 samplesize=numeric(),
                 group_cn=numeric(),
                 group_mci=numeric(),
                 group_ad=numeric(),
                 kruskal_h=numeric(),
                 p_value=numeric(),
                 mean=numeric(),
                 iqd=numeric())

for (feature in c( "adni_fdg",
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
                   "ravlt_immediate"
)) {
  
  print(paste0(":::::::::::::::::::::::: ",feature," :::::::::::::::::::::::::"))
  df<-bigdata[!is.na(bigdata[feature]),]  #Remove when feature metric is null
  df<-df[c('participant_id','session_id','diagnosis',feature)]
  df<-subset(df,diagnosis!='')
  df$diagnosis<-as.factor(df$diagnosis)
  df$participant_id<-as.factor(df$participant_id)
  df$session_id<-as.factor(df$session_id)
  
  # select random row for each participant
  random_rows <- df %>%
    group_by(participant_id) %>%
    slice_sample(n = 1)
  random_rows<-random_rows[c("diagnosis",feature)]
  str(random_rows)
  
  formula<-as.formula(paste(feature," ~ diagnosis"))
  
  kt<-kruskal.test( eval(formula),data=random_rows)
  
  m_mean<-mean(random_rows[[feature]],na.rm=TRUE)
  m_iqr<-IQR(random_rows[[feature]],na.rm=TRUE)

  row<-cbind(biomarker=feature,
             samplesize=nrow(random_rows),
             group_cn=nrow(subset(random_rows,diagnosis=="CN")),
             group_mci=nrow(subset(random_rows,diagnosis=="MCI")),
             group_ad=nrow(subset(random_rows,diagnosis=="AD")),
             kruskal_h=kt$statistic,
             p_value=kt$p.value,
             m_mean,
             m_iqr)
  eval<-rbind(eval,row)
  
  
  feature_label<-feature
  if(feature=="ravlt_immediate"){
    feature_label<-"RAVLT (Immediate)"
  } 
  if(feature=="cdr_sb"){
    feature_label<-"Clinical Dementia Rating Scale"
  } 
  
  random_rows$diagnosis <- factor(random_rows$diagnosis, levels = c("CN", "MCI", "AD"))
  
  gg_density<-ggplot(random_rows,aes(x=!!sym(feature),fill=diagnosis))+
    geom_density(alpha=0.5)+
    labs(x=feature_label,y="Density",fill="Diagnosis")+
    theme(
      panel.background = element_rect(fill = "white"),   # Set background color
      panel.grid = element_line(color = "#efefef"),           # Set grid line color
      plot.title = element_text(hjust = 0.5)     
    ) 
  
  gg_box<-ggplot(random_rows, aes_string(x = "diagnosis", y = feature, fill = "diagnosis")) +
    geom_boxplot() +
    labs(x = "Diagnosis", y = feature_label,fill="Diagnosis")+
    theme(
      panel.background = element_rect(fill = "white"),   # Set background color
      panel.grid = element_line(color = "#efefef"),           # Set grid line color
      plot.title = element_text(hjust = 0.5)     
    ) 
  
  combined_grob <- arrangeGrob(gg_box, gg_density, ncol = 2)
  grid.draw(combined_grob)
  
  # Add labels
  grid.text("A", x = unit(0.02, "npc"), y = unit(0.95, "npc"), just = c("center", "top"))
  grid.text("B", x = unit(0.52, "npc"), y = unit(0.95, "npc"), just = c("center", "top"))
  
  ggsave(paste0("Q1_plot_",feature,".pdf"), plot = combined_grob, width = 10, height = 5)
  
  
}
write.csv(eval,'Q1_kruskal_wallis.csv')
