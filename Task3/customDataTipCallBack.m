
function output_txt = customDataTipCallBack(src,evt)
% evt.Target.DataTipTemplate.DataTipRows.Label
% evt.Target.DataTipTemplate.DataTipRows.Value
% evt.Target.DataTipTemplate.DataTipRows.Format
output_txt = evt.Target.UserData;
