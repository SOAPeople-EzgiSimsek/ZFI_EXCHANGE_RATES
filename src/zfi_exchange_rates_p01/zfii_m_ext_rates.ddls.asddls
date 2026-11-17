@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Manuel Kur Çekme Uygulaması View'
//@Metadata.ignorePropagatedAnnotations: true
define root view entity ZFII_M_EXT_RATES
  as select from zfit_m_ext_rates
{
 key xguid  as Xguid,
      rate   as Rate,
      waers1 as Waers1,
      waers2 as Waers2,
      kurtr  as Kurtr,
      instr  as Instr,
      rundt  as Rundt,
      runtm  as Runtm
}
