(* Agent Layer — prelude for executable spec *)

(* === Types === *)

type cadence = Inbox | Daily | Weekly | Monthly | Quarterly | Yearly | Adhoc

type input_item = {
  id: string;
  from: string;
  content: string;
  cadence: cadence;
}

type op =
  | Reply of { message: string }
  | Send of { to_: string; message: string; body: string option }
  | Noop of { reason: string }
  | Ack of { reason: string }
  | Surface of { desc: string }
  | Commit of { artifact: string }

type gtd =
  | Do of op
  | Defer of { reason: string }
  | Delegate of { to_: string }
  | Delete of { reason: string }

(* === Interface constraints === *)

let agent_interface = ["cn input"; "cn out"]

let agent_cannot = [
  "access filesystem";
  "execute commands";
  "call APIs";
  "list inbox";
  "choose processing order"
]

let agent_can_only = ["call cn input"; "call cn out"]

(* === Input === *)

let cn_input_returns = {
  id = "abc123";
  from = "pi";
  content = "Please review";
  cadence = Inbox;
}

let all_cadences = [Inbox; Daily; Weekly; Monthly; Quarterly; Yearly; Adhoc]

(* === Output === *)

let gtd_options = ["do"; "defer"; "delegate"; "delete"]

let all_operations = ["reply"; "send"; "noop"; "ack"; "surface"; "commit"]

(* === Parsing cn out commands === *)

let parse_cn_out cmd =
  (* TODO: Implement actual parsing - this is a stub that will fail *)
  ignore cmd;
  failwith "cn out parsing not implemented"

(* === Type representations === *)

let type_op = "type op = Reply of {message: string} | Send of {to_: string; message: string; body: string option} | Noop of {reason: string} | Ack of {reason: string} | Surface of {desc: string} | Commit of {artifact: string}"

let type_gtd = "type gtd = Do of op | Defer of {reason: string} | Delegate of {to_: string} | Delete of {reason: string}"

(* === Auto notification === *)

let auto_notify = true
