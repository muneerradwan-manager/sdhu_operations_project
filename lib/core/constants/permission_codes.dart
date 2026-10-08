/// Permission codes — must match the `permissions.code` values seeded in the DB
/// (see supabase/migrations/0073_granular_permissions.sql).
///
/// One code per action. Sections (`employees`, `seasons`, …) are headings in
/// the catalog, not grants: the `.view` action of a section is what opens it.
/// What an action needs before it works (assigning members needs seeing
/// employees, deciding needs seeing the queue) lives in the DB table
/// `permission_prerequisites`, which both the editor UI and two DB triggers
/// enforce — a grant cannot exist without its ground.
class PermissionCodes {
  const PermissionCodes._();

  // -------------------------------------------------------------- employees
  static const employeesView = 'employees.view';
  static const employeesCreate = 'employees.create';
  static const employeesEdit = 'employees.edit';
  static const employeesDelete = 'employees.delete';
  static const employeesSuspend = 'employees.suspend';
  static const employeesExternal = 'employees.external';
  static const employeesDocuments = 'employees.documents';

  /// Resetting someone else's password. Deliberately not folded into
  /// [employeesEdit]: correcting a record and taking over a login are not the
  /// same trust (see migration 0072).
  static const employeesPassword = 'employees.password';

  /// Changing someone else's email address — the login itself. Its own code
  /// for the same reason the password has one (see migration 0076).
  static const employeesEmail = 'employees.email';

  // -------------------------------------------------------------- approvals
  static const approvalsView = 'approvals.view';
  static const approvalsDecide = 'approvals.decide';

  // ---------------------------------------------------------------- seasons
  static const seasonsView = 'seasons.view';

  /// Setting the current season — the highest-leverage single action in the
  /// app: it reslices files, master data, reports and the dashboard for
  /// everyone at once.
  static const seasonsSwitch = 'seasons.switch';
  static const seasonsParticipantsView = 'seasons.participants_view';
  static const seasonsParticipantsManage = 'seasons.participants_manage';

  // ---------------------------------------------------------------- modules
  static const modulesViewAll = 'modules.view_all';
  static const modulesCreate = 'modules.create';
  static const modulesEdit = 'modules.edit';
  static const modulesDelete = 'modules.delete';

  /// Releasing a file to its members (and taking it back). Separate from
  /// [modulesEdit] because activation notifies everyone assigned — it is a
  /// send, not a correction.
  static const modulesActivate = 'modules.activate';
  static const modulesMembers = 'modules.members';

  /// Writing the descriptive duty lists onto a file — the file's own and its
  /// roles'. Since 0105 that is ALL this code is: the lists carry no states,
  /// and the personal tasks moved out of the files entirely (see [tasksAssign]).
  static const modulesTasks = 'modules.tasks';

  static const modulesReports = 'modules.reports';

  // ----------------------------------------------------------------- export
  /// Taking data out of the app — and, since 0100, taking out data the holder
  /// cannot open on screen.
  ///
  /// **The second most powerful grant in the system after admin**, and it has
  /// to be, because the instruction was that whoever may export may export any
  /// type. That could not be done in Dart: offering the employees to somebody
  /// without `employees.view` would produce an EMPTY FILE, silently, since
  /// `profiles_select` returns him nothing — and an empty export is worse than
  /// a refusal, because he believes he has the data. So 0100 widens the row
  /// policies themselves.
  ///
  /// Two fences survive it: a holder still cannot read the complaints or the
  /// evaluations filed about HIMSELF. See 0100.
  static const exportData = 'export.data';

  // -------------------------------------------------------------------- map
  /// Opening the season map. The RPC behind it still narrows per reader — a
  /// member would see the places of his own files — so this decides who may
  /// open the PAGE, not what is on it.
  static const mapView = 'map.view';

  // ------------------------------------------------------------------ tasks
  /// Writing a task onto ANOTHER person's list (0105). Not what anyone needs
  /// for their own list — that is not a grant at all, everyone holds it by
  /// existing. The personal task system has no relation to the operational
  /// files, which is why this does not live under `modules.`.
  static const tasksAssign = 'tasks.assign';

  /// Reading every assigned task in the mission rather than only one's own
  /// (0117). Its own code because the two are different trusts: assigning is
  /// giving work out, and this is watching everybody else's.
  ///
  /// It exists at all because 0105's row policy already allowed the wider read
  /// and no query in the app ever asked for it — oversight that is permitted
  /// and unreachable is worse than oversight that is refused, because nobody
  /// finds out it is missing.
  ///
  /// It does NOT open a man's own notebook, and cannot: the policy's
  /// `created_by <> profile_id` guard sits in front of every branch this grant
  /// touches.
  static const tasksViewAll = 'tasks.view_all';

  // --------------------------------------------------------------- check-in
  //
  // Filing your OWN arrival needs no code at all, and that is deliberate: a
  // system in which only certain people may report where they are is a system
  // that does not know where anybody is. Standing at the place with its code in
  // front of you is the credential (0098).

  /// Reading who is present, everywhere. Somebody's own arrivals are always
  /// readable to him without this — the policy's `profile_id = auth.uid()`
  /// clause covers that.
  static const checkinBoard = 'checkin.board';

  /// Seeing, printing and sharing the codes. The secret is printable, so who
  /// may read it is exactly who may print it.
  static const checkinCodes = 'checkin.codes';

  /// Regenerating one, which stops every poster already on a wall from working.
  /// A different trust from printing, the way `reports.publish` is a different
  /// trust from `reports.edit` — and it requires [checkinCodes], since voiding
  /// forty posters means being able to see them first.
  static const checkinRotate = 'checkin.rotate';

  // -------------------------------------------------------------- reference
  static const referenceView = 'reference.view';
  static const referenceEdit = 'reference.edit';
  static const referenceDelete = 'reference.delete';
  static const referenceImport = 'reference.import';

  // ---------------------------------------------------------------- reports
  static const reportsViewAll = 'reports.view_all';
  static const reportsCreate = 'reports.create';
  static const reportsEdit = 'reports.edit';
  static const reportsDelete = 'reports.delete';

  /// Publishing puts a report before the whole mission; correcting a cell does
  /// not. Two different trusts, two codes.
  static const reportsPublish = 'reports.publish';

  // ---------------------------------------------------------- notifications
  /// One person.
  static const notificationsSend = 'notifications.send';

  /// Everyone in one operational file.
  static const notificationsBroadcastModule = 'notifications.broadcast_module';

  /// Everyone with a working account.
  static const notificationsBroadcastAll = 'notifications.broadcast_all';

  // ------------------------------------------------------------ permissions
  static const permissionsView = 'permissions.view';
  static const permissionsManage = 'permissions.manage';

  // ------------------------------------------------------------------ audit
  /// Reading the record of who did what. Reading only — the log has no write
  /// permission at all: rows are written by the database's own triggers.
  static const auditView = 'audit.view';

  // ------------------------------------------------------------- complaints
  /// Filing one is deliberately absent from this list. Anybody with a working
  /// account may complain; a record of what went wrong that only some people
  /// may write is not a record of what went wrong.

  /// Reading the whole register — everyone's complaints, not just your own.
  static const complaintsView = 'complaints.view';

  /// Taking part in a thread you are neither side of.
  static const complaintsReply = 'complaints.reply';

  /// Ending the conversation. The complaint stands; nobody may add to it.
  static const complaintsLock = 'complaints.lock';

  /// Calling a complaint unfounded, which takes it out of the count that
  /// suspends an account — and so can lift a suspension. That is why the DB
  /// makes it require [employeesSuspend] (see migration 0079).
  static const complaintsDismiss = 'complaints.dismiss';

  static const complaintsDelete = 'complaints.delete';

  // ------------------------------------------------------------ evaluations
  /// FILLING one is deliberately absent from this list, and the absence is the
  /// design. An evaluation reaches its evaluator by NAME, the way a file reaches
  /// its members by assignment (see migration 0084). A permission would say
  /// "whoever is trusted may judge whoever he likes", and an appraisal nobody
  /// asked for is not an appraisal.
  ///
  /// None of these has anything to do with the five-star peer rating inside a
  /// finished operational file (0059). That one is not permissioned at all — it
  /// is membership — and it stays exactly as it was.

  /// Reading the whole register: every sheet, its marks, and who wrote it. The
  /// evaluator is not a secret from the office — only from the person he judged,
  /// which row security enforces rather than this code.
  static const evaluationsView = 'evaluations.view';

  /// Building and editing the forms — the questions, their answers and what
  /// each is worth. إدارة التقييم proper.
  static const evaluationsTemplates = 'evaluations.templates';

  /// Opening one: naming a subject and naming the evaluator. Separate from
  /// [evaluationsTemplates] because writing the paper and deciding who is
  /// judged by it are two different trusts.
  static const evaluationsAssign = 'evaluations.assign';

  static const evaluationsDelete = 'evaluations.delete';

  // -------------------------------------------------------------- incidents
  /// RAISING one is deliberately absent, for the same reason filing a complaint
  /// is: a system in which only certain people may report that a bus has broken
  /// down is a system that does not find out about the bus.

  /// Being on the receiving end of every urgent report in the mission. A duty
  /// rather than a privilege — whoever holds it is expected to answer them.
  static const incidentsReceive = 'incidents.receive';

  /// Taking one on and closing it. Separate from receiving because reading the
  /// register and being answerable for it are two different trusts, and the
  /// database makes this one require the other (see migration 0088).
  static const incidentsHandle = 'incidents.handle';

  /// Striking one off the register, and emptying the register (0121).
  ///
  /// Not folded into [incidentsHandle]: closing a report says "somebody went",
  /// deleting it says "this never happened", and the second is not the first
  /// with more confidence. Until 0121 the table had no delete policy at all, so
  /// this was nobody's — not even an administrator's.
  static const incidentsDelete = 'incidents.delete';

  // ----------------------------------------------------------------- travel
  /// Seeing his OWN journey is deliberately absent, for the same reason raising
  /// an incident is: a record of where a man is being sent that he himself
  /// cannot read is not a record worth keeping. Confirming his own arrival is
  /// absent for a sharper reason still — for a private car there is no airline
  /// feed and no gate, so the only person who can say he reached المدينة is the
  /// man who drove there (see migration 0129).

  /// Reading somebody else's travel — the section on an employee's page. The
  /// door of the feature, and it requires [employeesView]: you cannot read
  /// whose journey it is otherwise.
  static const travelView = 'travel.view';

  /// The whole season's board rather than one man's page.
  static const travelViewAll = 'travel.view_all';

  /// Entering and changing the flights themselves.
  static const travelEdit = 'travel.edit';

  /// Putting people on them, and moving them between them. Separate from
  /// [travelEdit] because whoever knows which people travel together is rarely
  /// the same person who types in flight numbers.
  static const travelAssign = 'travel.assign';

  /// Recording what actually happened — departures and arrivals.
  ///
  /// Its own code, and this is the split that matters most in the feature: the
  /// man standing at the gate ticking off sixty arrivals should be able to do
  /// exactly that and not to rewrite the timetable. The same argument
  /// [employeesPassword] makes against being folded into [employeesEdit].
  static const travelConfirm = 'travel.confirm';

  /// Erasing a trip entered by mistake. Cancelling one is a status and belongs
  /// to [travelEdit]; this is the other thing, and the database refuses it
  /// outright while anybody is still aboard.
  static const travelDelete = 'travel.delete';
}
