library(ggplot2)
library(dplyr)

df<-read.csv('~/datacommons/projects/adni3/Q4/hochberg_wilcox_all.csv')#hh.csv')

df <- df %>% 
  mutate(Group = paste(Var1, Var2, sep = "_"))

df2<-df %>%
    filter(Group %in% c("SMC_CN","SMC_EMCI","MCI_EMCI","MCI_LMCI","LMCI_AD"))#, "LMCI_EMCI","EMCI_LMCI"))

df2$Group[df2$Group=="SMC_CN"]<-"CN \u2192 SMC"
df2$Group[df2$Group=="SMC_EMCI"]<-"SMC \u2192 EMCI"
df2$Group[df2$Group=="MCI_EMCI"]<-"EMCI \u2192 MCI"
df2$Group[df2$Group=="MCI_LMCI"]<-"MCI \u2192 LMCI"
df2$Group[df2$Group=="LMCI_AD"]<-"LMCI \u2192 AD"


# Split the data frame by group and apply ecdf
df_list <- split(df2, df2$Group)
df_cumulative <- do.call(rbind, lapply(df_list, function(group_df) {
  data.frame(Group = unique(group_df$Group),
             Freq = group_df$Freq,
             CumulativeFreq = ecdf(group_df$Freq)(group_df$Freq))
}))

plt1<-ggplot(df_cumulative, aes(x = Freq, y = CumulativeFreq, color = Group)) +
  geom_line() +
  geom_abline(intercept = 0, slope = 20, color = "red", linetype = "dashed", linewidth = 1.2) +
  labs(title = "Cumulative Distribution by p-value Comparison",
       x = "Corresponding Null p-Value",
       y = "Cumulative Observed p-value",
       color = "Group") +
  theme_minimal()


df3<-df %>%
  filter(Group %in% c("MCI_LMCI","LMCI_AD") & Freq< 0.001 
         & measurement!="LinesToRender" & measurement!="LinesToRender-asymidx")

df3$measurement[df3$measurement=="TractsToRender"]<-"Streamlines"
df3$measurement[df3$measurement=="voxelvolume"]<-"Tract volume"
df3$measurement[df3$measurement=="voxelvolume-asymidx"]<-"Tract volume asym"
df3$measurement[df3$measurement=="TractsToRender-asymidx"]<-"Streamline asym"
df3$measurement[df3$measurement=="MeanTractLen_StdDev"]<-"Tract length variability"
df3$measurement[df3$measurement=="MeanTractLen-asymidx"]<-"Tract length asym"
df3$measurement[df3$measurement=="MeanTractLen_StdDev-asymidx"]<-"Tract length variability asym"
df3$measurement[df3$measurement=="MeanTractLen"]<-"Tract length"
df3$measurement[df3$measurement=="stddevADC-asymidx"]<-"ADC variability asym"
df3$measurement[df3$measurement=="meanFA-asymidx"]<-"FA asym"
df3$measurement[df3$measurement=="meanADC-asymidx"]<-"ADC asym"
df3$measurement[df3$measurement=="stddevADC"]<-"ADC variability"
df3$measurement[df3$measurement=="meanADC"]<-"ADC"
df3$measurement[df3$measurement=="stddevFA-asymidx"]<-"FA variability asym"
df3$measurement[df3$measurement=="stddevFA"]<-"FA variability"
df3$measurement[df3$measurement=="meanFA"]<-"FA"

df3<-subset(df3,measurement!="Streamlines" & measurement!="Streamline asym")

measurement_freq<-as.data.frame(table(df3$measurement))
measurement_freq <- measurement_freq[order(-measurement_freq$Freq),]

# Create bar chart
plt2<-ggplot(measurement_freq, aes(x = reorder(Var1, -Freq), y = Freq)) +
  geom_bar(stat = "identity") +
  labs(title = "Frequency of measurement exhibiting significant differences between groups",
       x = "Measurement",
       y = "Frequency") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1))

