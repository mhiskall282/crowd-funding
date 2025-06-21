import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Array "mo:base/Array";

actor app {

  // === Types ===
  type Student = {
    id: Principal;
    name: Text;
    gpa: Float;
    program: Text;
    email: Text;
    wallet: Text;
    amount_requested: Nat;
    approved: Bool;
  };

  type Proposal = {
    id: Nat;
    description: Text;
    votes: Nat;
    executed: Bool;
  };

  type RepaymentPlan = {
    studentId: Principal;
    totalOwed: Nat;
    amountPaid: Nat;
    active: Bool;
  };

  // === Stable Variables ===
  stable var students: [Student] = [];
  stable var proposals: [Proposal] = [];
  stable var repayments: [RepaymentPlan] = [];
  stable var poolBalance: Nat = 0;
  stable var nextProposalId: Nat = 0;

  // === Student Registration ===
  public shared({ caller }) func registerStudent(student: Student): async Result.Result<Text, Text> {
    if (student.id != caller) {
      return #err("Student ID does not match caller.");
    };

    for (s in students.vals()) {
      if (s.id == caller) {
        return #err("Student already registered.");
      }
    };

    students := Array.append(students, [student]);
    return #ok("Student registered.");
  };

  public query func getStudents(): async [Student] {
    students
  };

  public query func getStudent(id: Principal): async ?Student {
    for (s in students.vals()) {
      if (s.id == id) {
        return ?s;
      }
    };
    return null;
  };

  // === Scholarship Pool ===
  public shared func fundPool(amount: Nat): async Text {
    poolBalance += amount;
    return "Funding successful.";
  };

  public query func getPoolBalance(): async Nat {
    poolBalance
  };

  public shared func approveFunding(studentId: Principal): async Text {
    var updated: [Student] = [];
    var found: Bool = false;

    for (s in students.vals()) {
      if (s.id == studentId and not s.approved and s.amount_requested <= poolBalance) {
        poolBalance -= s.amount_requested;
        let updatedStudent: Student = {
          id = s.id;
          name = s.name;
          gpa = s.gpa;
          program = s.program;
          email = s.email;
          wallet = s.wallet;
          amount_requested = s.amount_requested;
          approved = true;
        };
        updated := Array.append(updated, [updatedStudent]);
        found := true;
      } else {
        updated := Array.append(updated, [s]);
      }
    };

    students := updated;

    if (found) {
      return "Funding approved.";
    } else {
      return "Student not found or not eligible.";
    }
  };

  // === DAO Governance ===
  public shared func createProposal(desc: Text): async Text {
    if (Text.size(desc) == 0) {
      return "Description cannot be empty.";
    };
    if (Text.size(desc) > 280) {
      return "Description too long.";
    };

    let proposal: Proposal = {
      id = nextProposalId;
      description = desc;
      votes = 0;
      executed = false;
    };

    proposals := Array.append(proposals, [proposal]);
    nextProposalId += 1;
    return "Proposal created.";
  };

  public query func getProposals(): async [Proposal] {
    proposals
  };

  public shared func vote(id: Nat): async Text {
    var updated: [Proposal] = [];
    var found: Bool = false;

    for (p in proposals.vals()) {
      if (p.id == id and not p.executed) {
        let updatedProposal: Proposal = {
          id = p.id;
          description = p.description;
          votes = p.votes + 1;
          executed = p.executed;
        };
        updated := Array.append(updated, [updatedProposal]);
        found := true;
      } else {
        updated := Array.append(updated, [p]);
      }
    };

    proposals := updated;

    if (found) {
      return "Vote recorded.";
    } else {
      return "Proposal not found or already executed.";
    }
  };

  public shared func execute(id: Nat): async Text {
    var updated: [Proposal] = [];
    var found: Bool = false;

    for (p in proposals.vals()) {
      if (p.id == id and not p.executed and p.votes >= 3) {
        let updatedProposal: Proposal = {
          id = p.id;
          description = p.description;
          votes = p.votes;
          executed = true;
        };
        updated := Array.append(updated, [updatedProposal]);
        found := true;
      } else {
        updated := Array.append(updated, [p]);
      }
    };

    proposals := updated;

    if (found) {
      return "Proposal executed.";
    } else {
      return "Proposal not found or not eligible.";
    }
  };

  // === Repayment Tracking ===
  public shared func createRepaymentPlan(studentId: Principal, amount: Nat): async Text {
    let plan: RepaymentPlan = {
      studentId = studentId;
      totalOwed = amount;
      amountPaid = 0;
      active = true;
    };

    repayments := Array.append(repayments, [plan]);
    return "Repayment plan created.";
  };

  public shared func recordPayment(studentId: Principal, payment: Nat): async Result.Result<Text, Text> {
    var updated: [RepaymentPlan] = [];
    var found: Bool = false;

    for (r in repayments.vals()) {
      if (r.studentId == studentId and r.active) {
        let newAmount = r.amountPaid + payment;
        let updatedPlan: RepaymentPlan = {
          studentId = r.studentId;
          totalOwed = r.totalOwed;
          amountPaid = newAmount;
          active = newAmount < r.totalOwed;
        };
        updated := Array.append(updated, [updatedPlan]);
        found := true;
      } else {
        updated := Array.append(updated, [r]);
      }
    };

    repayments := updated;

    if (found) {
      return #ok("Payment recorded.");
    } else {
      return #err("No active repayment plan found.");
    }
  };

  public query func getRepaymentPlans(): async [RepaymentPlan] {
    repayments
  };

  public query func getRepaymentPlan(studentId: Principal): async ?RepaymentPlan {
    for (r in repayments.vals()) {
      if (r.studentId == studentId) {
        return ?r;
      }
    };
    return null;
  };
};