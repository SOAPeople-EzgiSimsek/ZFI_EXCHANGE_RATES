@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Manuel Kur Çekme Uygulaması  PV'
//@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZFIC_M_EXT_RATES 
provider contract transactional_query
  as projection on  ZFII_M_EXT_RATES
{
    key Xguid,
    Rate,
    Waers1,
    Waers2,
    Kurtr,
    Instr,
    Rundt,
    Runtm
}
