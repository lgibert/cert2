*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.

Library    RPA.Browser.Selenium
Library    RPA.FileSystem
Library    RPA.HTTP
Library    String
Library    RPA.Tables
Library    Collections
Library    RPA.Database
Library    RPA.PDF
Library    RPA.Archive

*** Variables ***
${url}  https://robotsparebinindustries.com/#/robot-order
${urlFile}  https://robotsparebinindustries.com/orders.csv
${directory}=   ${OUTPUT DIR}${/}orderFile
${index}

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website 

*** Keywords ***
Get orders
    [Arguments]  ${dataTableFile}
    Set Global Variable  ${index}  ${-1}
    ${lDataTableFile}=  Get Length    ${dataTableFile}
    ${dataList}=  Create List
    FOR  ${row}  IN RANGE  ${lDataTableFile}
        ${index}=  Evaluate  ${index}+1
        ${dataRow}=  Get Table Row    ${dataTableFile}    ${index}
        Log  ${dataRow}
        Append To List  ${dataList}  ${dataRow}
    END
    [Return]  ${dataList}
    
*** Keywords ***
Open the robot order website
    Open Available Browser  ${url}
    ${directory_not_exists}=    Does directory not exist    ${directory}
    ${file_exists}=  Does File Exist    ${directory}${/}orders.csv
    IF  ${directory_not_exists} == ${True}
        Create Directory  ${OUTPUT DIR}${/}orderFile
    END
    IF  ${file_exists} == ${True}
        Remove File    ${directory}${/}orders.csv  
    END
    Download  ${urlFile}  target_file=${directory}  overwrite= True
    ${dataTableFile}=  Read table from CSV    ${directory}${/}orders.csv
    ${orders}=  Get orders    ${dataTableFile}
    Log  ${orders}
    FOR    ${row}    IN    @{orders}
        Close the anoying modal
        Fill the form    ${row}
        Click Element  //*[@id="preview"]
        Submit the order
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
    END
    Create a ZIP file of the receipts
    
*** Keywords ***
Close the anoying modal
    Click Element  //*[@id="root"]/div/div[2]/div/div/div/div/div/button[1]

*** Keywords ***
Fill the form
    [Arguments]  ${row}
    Log  ${row}
    Select From List By Value  //*[@id="head"]  ${row}[Head]
    ${bodyElements}=  Get WebElements    //*[@id="root"]/div/div[1]/div/div[1]/form/div[2]/div/div/label/input
    ${nbBodyElements}=  Get Length  ${bodyElements}
    ${index}=  Set Variable  ${-1}
    FOR  ${element}  IN RANGE  ${nbBodyElements}
        ${index}=  Evaluate  ${index}+1
        ${check}=  Get Value  ${bodyElements}[${index}]
        IF  ${check} == ${row}[Body]
            Click Element  ${bodyElements}[${index}]
        END
    END
    Input Text    css:input[placeholder="Enter the part number for the legs"]    ${row}[Legs]
    Input Text    //*[@id="address"]    ${row}[Address]

*** Keywords ***
Submit the order
    Wait Until Keyword Succeeds    10x    strict:1s  Click Element  //*[@id="order"]
    Sleep  2s
    ${isAlertExist}=  Run Keyword And Ignore Error  Element Should Not Be Visible  //*[@Class="alert alert-danger"]
    Log  ${isAlertExist}[0]
    IF  "${isAlertExist}[0]" != "PASS"
        Wait Until Keyword Succeeds    10x    strict:1s  Click Element  //*[@id="order"]
    ELSE
        Log  Order généré
    END
*** Keywords ***
Store the receipt as a PDF file
    [Arguments]  ${row}
    ${isReceiptOk}=  Does Page Contain Element  id:receipt
    Log  ${row}
    IF  ${isReceiptOk}
        #Wait Until Element Is Visible    id:receipt
        ${orderResult}=  Get Element Attribute    id:receipt    outerHTML
        Html To Pdf  ${orderResult}  ${OUTPUT_DIR}${/}${row}.pdf
        ${pdf}=  Set Variable  ${OUTPUT_DIR}${/}${row}.pdf
    ELSE
        Submit the order
        ${orderResult}=  Get Element Attribute    id:receipt    outerHTML
        Html To Pdf  ${orderResult}  ${OUTPUT_DIR}${/}${row}.pdf
        ${pdf}=  Set Variable  ${OUTPUT_DIR}${/}${row}.pdf
    END
    [Return]  ${pdf}
*** Keywords ***
Take a screenshot of the robot
    [Arguments]  ${row}
    Wait Until Element Is Visible    id:robot-preview
    Screenshot  id:robot-preview  ${OUTPUT_DIR}${/}${row}.png
    ${screenshot}=  Set Variable  ${OUTPUT_DIR}${/}${row}.png
    [Return]  ${screenshot}

*** Keywords ***
Embed the robot screenshot to the receipt PDF file    
    [Arguments]  ${screenshot}    ${pdf}
    Add Watermark Image To PDF
    ...             image_path=${screenshot}
    ...             source_path=${pdf}
    ...             output_path=${pdf}

*** Keywords ***
Go to order another robot
    Click Element  //*[@id="order-another"]

*** Keywords ***
Create a ZIP file of the receipts
    ${zipFileName}=  Find Files  ${OUTPUT_DIR}${/}*.pdf
    Log  ${zipFileName}
    Archive Folder With Zip    ${directory}${/}    orders.zip
    @{files}  List Archive  orders.zip
    FOR  ${file}  IN  ${files}
        Log  ${file}
    END
    Add To Archive    ${zipFileName}    orders.zip