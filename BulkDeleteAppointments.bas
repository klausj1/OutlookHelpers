'' Copyright (c) 2014 by Joachim Schlosser
' http://www.schlosser.info
'
' All rights reserved.
'
' Redistribution and use in source and binary forms, with or without modification,
' are permitted provided that the following conditions are met:
'
' 1. Redistributions of source code must retain the above copyright notice,
' this list of conditions and the following disclaimer.
'
' 2. Redistributions in binary form must reproduce the above copyright notice,
' this list of conditions and the following disclaimer in the documentation
' and/or other materials provided with the distribution.
'
' THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
' IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
' DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
' FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
' DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
' SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
' CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
' OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
' OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
'
' Description of functionality at  http://www.schlosser.info/outlook-delete-multiple-appointments
' Beschreibung der Funktionalität: http://www.schlosser.info/outlook-viele-termine-absagen
'
Private Type dateRange
    startDate As Date
    endDate As Date
    datNull As Date
'    Const datNull As Date = #1/1/4501#
End Type

' Delete all selected calendar items and send the same message on all
Public Sub BulkDeleteAppointments()
    Dim oAppt As Object
    Dim itemsToDelete As Object
    Dim cancelMsg As String
    Dim datRange As dateRange
    Dim itemCount As Integer
    itemCount = 0
    
    ' did user select date range or individual items?
    datRange = selectedDateRange()
    
    If Application.ActiveExplorer.Selection.Count > 0 Then
        Set itemsToDelete = Application.ActiveExplorer.Selection
    ElseIf (datRange.startDate <> datRange.datNull) And (datRange.endDate <> datRange.datNull) Then
        ' auto-select all calendar items in range
        Set itemsToDelete = selectFromDateRange(datRange)
    End If
    
    ' only proceed if items are selected by now, either automatically or manually
    If itemsToDelete.Count > 0 Then
        For Each oAppt In itemsToDelete
            itemCount = itemCount + 1
        Next oAppt
        If (itemCount > 100) Then
          MsgBox ("Too many entries. Max 100 are deleted in one go. Aborted!")
        Else
        ' Show found entries, get confirmation string
            cancelMsg = InputBox(Prompt:="Selected Date Range: " & datRange.startDate & " - " & datRange.endDate & "." & Chr$(13) & Chr$(13) & "Number of found Items: " & itemCount _
            & Chr$(13) & Chr$(13) & "Enter your cancel message below please. Check the info above, there will be no further confirmation.", _
                  Title:="ENTER YOUR MESSAGE", Default:="I am on vacation.")
            If (cancelMsg <> "") Then
                For Each oAppt In itemsToDelete
                    DeleteItemWithDefaultMessage oAppt, cancelMsg
                Next oAppt
            End If
        End If
    End If
End Sub

' Check selected date range
' from http://msdn.microsoft.com/en-us/library/office/ff869571(v=office.15).aspx
Private Function selectedDateRange() As dateRange
     Dim oView As Outlook.View
     Dim oCalView As Outlook.CalendarView
     Dim oExpl As Outlook.Explorer
     Dim oFolder As Outlook.Folder
     Dim datRange As dateRange
     Dim oAppt As Outlook.AppointmentItem
     
'     Const datNull As Date = #1/1/4501#
     
     ' Obtain the calendar view using
     ' Application.ActiveExplorer.CurrentFolder.CurrentView.
     ' If you use oExpl.CurrentFolder.CurrentView,
     ' this code will not operate as expected.
     Set oExpl = Application.ActiveExplorer
     Set oFolder = Application.ActiveExplorer.CurrentFolder
     Set oView = oExpl.CurrentView
     
     ' Check whether the active explorer is displaying a calendar view.
     If oView.ViewType = olCalendarView Then
        Set oCalView = oExpl.CurrentView
        ' Create the appointment using the values in
        ' the SelectedStartTime and SelectedEndTime properties as
        ' appointment start and end times.
        datRange.startDate = oCalView.SelectedStartTime
        datRange.endDate = oCalView.SelectedEndTime
        datRange.datNull = #1/1/4501#
        selectedDateRange = datRange
     End If
End Function

' select all calendar items in date range
' includes code from http://msdn.microsoft.com/en-us/library/office/ff867729(v=office.15).aspx
Private Function selectFromDateRange(datRange As dateRange) As Outlook.Items
    Dim oCalendar As Outlook.Folder
    Dim oItems As Outlook.Items
    Dim oItemsInDateRange As Outlook.Items
    Dim oReturnItems As Outlook.Items
    Dim oAppt As Outlook.AppointmentItem
    Dim strRestriction As String
    strRestriction = "[Start] >= '" & (Format(datRange.startDate, "DDDDD HH:NN")) _
        & "' AND [End] <= '" & (Format(datRange.endDate, "DDDDD HH:NN")) & "'"
    'Check the restriction string
    Debug.Print strRestriction
    Set oCalendar = Application.ActiveExplorer.CurrentFolder
    Set oItems = oCalendar.Items
    oItems.IncludeRecurrences = True
    oItems.Sort "[Start]"
    'Restrict the Items collection for the selected date range
    Set oItemsInDateRange = oItems.Restrict(strRestriction)
    'Sort final results
    oItemsInDateRange.Sort "[Start]"
    If oItemsInDateRange.Count > 0 Then
        Set selectFromDateRange = oItemsInDateRange
    End If
End Function

' The core function for bulk delete
Sub DeleteItemWithDefaultMessage(oItem, cancelMsg)
    Dim strMessageClass As String
    Dim oAppointItem As Outlook.AppointmentItem
    Dim myMtg As Outlook.MeetingItem
    strMessageClass = oItem.MessageClass
    If (InStr(1, strMessageClass, "IPM.Appointment") = 1) Then  ' Only operate on Calendar Entry.
        Set oAppointItem = oItem
        Select Case oAppointItem.MeetingStatus
          Case olNonMeeting                                     'Just a private meeting
                'MsgBox ("Own Appointment, nobody invited: " + oAppointItem.Subject)
                oAppointItem.Delete
          Case olMeeting                                        'Own meeting (I am the invitor)
                'MsgBox ("Own Appointment: " + oAppointItem.Subject)
                oAppointItem.MeetingStatus = olMeetingCanceled
                oAppointItem.Body = cancelMsg
                oAppointItem.Save
                oAppointItem.Send
          Case olMeetingReceived                                'Received meeting invitation
                'MsgBox ("Invited Appointment: " + oAppointItem.Subject)
                Set myMtg = oAppointItem.Respond(olMeetingDeclined, True, False)
                myMtg.Body = cancelMsg
                myMtg.Send
          Case olMeetingCanceled, olMeetingReceivedAndCanceled  'Received meeting invitation, updated afterwards
                MsgBox ("Meeting has already been canceled, just trying to delete: " + oAppointItem.Subject)
                oAppointItem.Delete
          Case Else
        End Select
    End If
End Sub

