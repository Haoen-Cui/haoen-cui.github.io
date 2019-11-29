library("shiny")
library("tidyverse")
library("stringr")
library("DT")

################################################################################

# define grading scheme
rubric <- round(seq(from = 2/3, to = 4.00, by = 1/3), digits = 2)
rubric <- c(0.00, rubric, 4.00)
names(rubric) <- c("F", 
                   "D-", "D", "D+", 
                   "C-", "C", "C+", 
                   "B-", "B", "B+", 
                   "A-", "A", "A+")
fail.grade <- c("F", "W")

# helper function to eliminate take care of honor grades
honor.convert <- function(grade) {
  grade.len <- nchar(as.character(grade))
  return(ifelse(substr(grade, start = grade.len, stop = grade.len) == "H", 
                # if yes, delete trailing "H" 
                substr(grade, start = 1, stop = grade.len - 1),
                # if no, keep letter grade
                substr(grade, start = 1, stop = grade.len))) 
}

# helper function to compute GPA
calculate.GPA <- function(hour, grade, grade.sys = rubric, 
                          exclusion = fail.grade) {
  grade.converted <- honor.convert(grade)
  grade.num <- ifelse(grade.converted %in% names(grade.sys), 
                      grade.sys[grade.converted], NA)
  idx.GPA <- which(!is.na(grade.num))
  idx.earned <- which(!(grade.converted %in% exclusion))
  GPA <- weighted.mean(grade.num[idx.GPA], hour[idx.GPA])
  GPA.Hours <- sum(hour[idx.GPA])
  Attempted.Hours <- sum(hour[grade != "Pass"])
  Earned.Hours <- sum(hour[idx.earned])
  num.count <- length(grade)
  num.zero.count <- sum(hour == 0)
  return(list(GPA = GPA, GPA.Hours = GPA.Hours, 
              Earned.Hours = Earned.Hours, Attempted.Hours = Attempted.Hours, 
              count = num.count, zero.count = num.zero.count))
}

# helper function to summarize GPA list object
summary.GPA <- function(GPA.info, grade, grade.sys = rubric) {
  # generate pretty output for grading system
  grade.sys.verbose <- paste(names(grade.sys), 
                             format(round(as.numeric(grade.sys), digits = 2), 
                                    nsmall = 2), # keep two decimal places
                             sep = " = ")
  grade.sys.summary <- rev(grade.sys.verbose) # reverse order: A+ --> F
  grade.sys.summary <- c(paste(grade.sys.summary[ 1: 3], collapse = "   "), 
                         paste(grade.sys.summary[ 4: 6], collapse = "   "), 
                         paste(grade.sys.summary[ 7: 9], collapse = "   "), 
                         paste(grade.sys.summary[10:12], collapse = "   "), 
                         grade.sys.summary[13]) # regroup into 3 entries per row
  # generate pretty output for GPA info
  paste("GPA Information of Currently Selected Courses", 
        "------------------------------------------------------------------------------------", 
        sprintf("GPA = %s / 4.00 ; ", 
                format(floor(GPA.info$GPA*100)/100, nsmall = 2)), 
        sprintf("GPA Hours = %s , ", 
                format(floor(GPA.info$GPA.Hours))), 
        "    i.e. hours included in GPA calculation; ", 
        sprintf("Attempted Hours = %s , ", 
                format(floor(GPA.info$Attempted.Hours))), 
        "    i.e. sum of all credit hours attempted (excluding AP and proficiency exams); ", 
        sprintf("Earned Hours = %s , ", 
                format(floor(GPA.info$Earned.Hours))), 
        "    i.e. sum of all credit hours awarded (including AP and proficiency exams); ", 
        sprintf("Total Number of Courses Selected = %s .", 
                format(floor(GPA.info$count))), 
        sprintf("Total Number of Zero-Credit Courses Selected = %s .", 
                format(floor(GPA.info$zero.count))), 
        "------------------------------------------------------------------------------------", 
        "NOTE:",
        "The above calculations are performed based on", 
        "    my understanding of UIUC (my undergraduate institution)'s grading system.", 
        "It may not reflect the system(s) used at other institutions,", 
        "    nor can I guarantee the correctness of my methodology (though tested).", 
        "A snapshot of my school's GPA scale: ", 
        paste(paste("    ", grade.sys.summary, sep = ""), collapse = "\n"), 
        "    (honor grades, i.e. grades with trailing 'H', ", 
        "        are treated the same as non-honor grades.)", 
        sep = "\n")
}

################################################################################

# Load data ---
file.src <- # direct link to online storage
  "https://drive.google.com/uc?export=download&id=1XzVYwz8KoWf_lnvAvC7mgEJXsxLVU8dM"
course.desc <- 
  bind_rows( # read in all six tabs
    openxlsx::read.xlsx(xlsxFile = file.src, sheet = 1), 
    openxlsx::read.xlsx(xlsxFile = file.src, sheet = 2), 
    openxlsx::read.xlsx(xlsxFile = file.src, sheet = 3), 
    openxlsx::read.xlsx(xlsxFile = file.src, sheet = 4), 
    openxlsx::read.xlsx(xlsxFile = file.src, sheet = 5), 
    openxlsx::read.xlsx(xlsxFile = file.src, sheet = 6)) 
course.desc <- course.desc %>% distinct() %>% # deduplicate
  mutate(Subject        = as.factor(str_split(Course.Number, " ", 
                                              simplify = TRUE)[, 1]), 
         Semester.Taken = factor(Semester.Taken, # define semester as ordinal 
                                 levels = c("Fall 2014", "Winter 2014-2015","Spring 2015", "Summer 2015",
                                            "Fall 2015", "Winter 2015-2016", "Spring 2016", "Summer 2016",
                                            "Fall 2016", "Spring 2017", "Summer 2017",
                                            "Fall 2017", "Spring 2018",
                                            "N/A"), # N/A for AP transfer credits
                                 ordered = TRUE), 
         Credit.Hour    = as.factor(Credit.Hour), 
         Grade          = as.factor(Grade)) %>% 
  mutate(Subject = recode_factor(Subject, # recode subject to full names
                                 "MATH" = "Mathematics", 
                                 "STAT" = "Statistics", 
                                 "CS"   = "Computer Science", 
                                 "ECE"  = "Electrical and Computer Engineering", 
                                 "FIN"  = "Finance", 
                                 "ECON" = "Economics", 
                                 "ACCY" = "Accountancy", 
                                 "ACE"  = "Agricultural and Consumer Economics", 
                                 "BADM" = "Business Administration", 
                                 "BUS"  = "Business", 
                                 "PHYS" = "Physics", 
                                 "CHEM" = "Chemistry", 
                                 "ENG"  = "Engineering", 
                                 "GEOG" = "Geography", 
                                 "IB"   = "Integrative Biology", 
                                 "PHIL" = "Philosophy",
                                 "CMN"  = "Communication", 
                                 "RHET" = "Rhetoric and Composition", 
                                 "BTW"  = "Business and Technical Writing", 
                                 "PSYC" = "Psychology", 
                                 "LER"  = "Labor and Employment Relations", 
                                 "ARTH" = "Art History", 
                                 "MUS"  = "Music"
                                 )) %>% 
  select(Subject, names(course.desc))

################################################################################

# Define UI for data download app ----
ui <- fluidPage(
  # App title ----
  titlePanel("Haoen CUI's Academic History at the University of Illinois at Urbana-Champaign", 
             windowTitle = "Haoen CUI - Academic History"),
  # Input ---
  wellPanel(
    # Checkbox
    checkboxGroupInput("show_vars", "Columns to show:", inline = TRUE, 
                       choices = names(course.desc), selected = names(course.desc)), 
    # Button
    downloadButton("downloadDataCSV", "Download Entire Dataset as CSV")), 
  # Output ---
  dataTableOutput("data_table"), 
  verbatimTextOutput("summary")
)

# Define server logic to display and download selected file ----
server <- function(input, output) {
  # dataTable: data_table
  output$data_table <- renderDataTable({ 
    dat <- course.desc[, input$show_vars, drop = FALSE]
    datatable(dat, filter = 'top', rownames = FALSE, 
              options = list(pageLength = 5))
    })
  # verbatimTextOutput: summary
  output$summary <- renderText({ 
    dat <- course.desc[input$data_table_rows_all, input$show_vars]
    GPA.info <- 
      calculate.GPA(hour  = as.numeric(as.character(dat$Credit.Hour)), 
                    grade = as.character(dat$Grade)) 
    summary.GPA(GPA.info)
    })
  # Downloadable CSV ----
  output$downloadDataCSV <- downloadHandler(
    filename = function() {
      paste("CUI.HAOEN.AcademicHistory", ".csv", sep = "")
    },
    content = function(file) {
      write.csv(course.desc, file, row.names = FALSE)
    })
}

# Create Shiny app ----
shinyApp(ui = ui, server = server)
