################ libraries
library(shiny)
library(readxl)
library(arules)
library(ggplot2)
library(DT)



################ ui
ui <- fluidPage (
  titlePanel("Data Science Project"),
  
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Choose Excel File", accept = ".xlsx"),
      numericInput("n_clusters", "Number of Clusters", value = 3, min = 1),
      numericInput("min_support", "Minimum Support", value = 0.01, min = 0, max = 1, step = 0.01),
      numericInput("min_confidence", "Minimum Confidence", value = 0.8, min = 0, max = 1, step = 0.01),
      actionButton("process_btn", "Process Data")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Graphs",
                 fluidRow(
                   column(6, plotOutput("payment_plot")),
                   column(6, plotOutput("age_plot"))
                 ),
                 fluidRow(
                   column(6, plotOutput("city_plot")),
                   column(6, plotOutput("hist_plot"))
                 )
        ),
        tabPanel("Cluster Results", DTOutput("cluster_table")),
        tabPanel("Association Rules", DTOutput("assoc_rules"))
      )
    )
  )
)




################ server logic
server <- function(input, output, session) {
  
  # Temporary data recording
  data <- reactiveVal(NULL)
  processed_data <- reactiveVal(NULL)
  assoc_rules <- reactiveVal(NULL)
  
  
  observeEvent(input$file, {
    req(input$file)
    data(read_xlsx(input$file$datapath))
  })
  
  
  observeEvent(input$process_btn, {
    req(data())
    cleaned_data <- data()
    cleaned_data <- unique(cleaned_data)
    cleaned_data <- na.omit(cleaned_data)
    
    ##### K-means clustering
    aggregated_data <- aggregate(total ~ customer + age, data = cleaned_data, sum)
    kmeans_result <- kmeans(aggregated_data[, c("age", "total")], centers = input$n_clusters)
    aggregated_data$Cluster <- kmeans_result$cluster
    processed_data(aggregated_data)
    
    # view K-means clustring
    output$cluster_table <- renderDT({ req(processed_data()); datatable(processed_data()) })
    
    
    
    ###### Association Rule Mining
    transactions <- as(cleaned_data, "transactions")
    rules <- apriori(transactions, parameter = list(supp = input$min_support, conf = input$min_confidence))
    assoc_rules(rules)
    
    # view association rules
    output$assoc_rules <- renderDT({ req(assoc_rules()); datatable(as(assoc_rules(), "data.frame")) })
  })

  
  
  ##### graphs
  # pie chart ==> total ~ payment type
  output$payment_plot <- renderPlot({
    req(data())
    payment_totals <- aggregate(total ~ paymentType, data = data(), sum)
    pie(payment_totals$total, labels = paste(payment_totals$paymentType, "\n",
                            round(100 * payment_totals$total / sum(payment_totals$total), 1), "%"),
                            col = rainbow(length(payment_totals$paymentType)), main = "Total Payments by Payment Type")
  })
  
  # Line Charts ==> total ~ age
  output$age_plot <- renderPlot({
    req(data())
    age_totals <- aggregate(total ~ age, data = data(), sum)
    plot(age_totals$age, age_totals$total, type = "o", col = "blue", main = "Total Payments by Age", xlab = "Age", ylab = "Total Amount")
  })
  
  # bar plot ==> total ~ city
  output$city_plot <- renderPlot({
    req(data())
    city_totals <- aggregate(total ~ city, data = data(), sum)
    city_totals <- city_totals[order(-city_totals$total), ]
    barplot(city_totals$total, names.arg = city_totals$city, col = rainbow(length(city_totals$city)),
            main = "Total Payments by City (Descending)", las = 2, xlab = "City", ylab = "Total Amount")
  })

  # hist plot ==> Distribution of Total Spending  
  output$hist_plot <- renderPlot({
    req(data())
    hist(data()$total, breaks = 20, col = "skyblue", main = "Distribution of Total Spending",
         xlab = "Total Spending", ylab = "Frequency", border = "white")
  })
}


# open the app
shinyApp(ui = ui, server = server)