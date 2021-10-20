import { GithubClient } from "./github.ts";
import { Command, EnumType } from "cliffy/command";
import { EditAction } from "./actions/edit.ts";
import {
  CreateBookAction,
  CreatePageAction,
  DeletePageAction,
  ShowAction,
} from "./actions/mod.ts";

const subCommandType = new EnumType(["edit", "delete", "create", "show"]);
const createSubCommandType = new EnumType(["book", "page"]);
const deleteubCommandType = new EnumType(["book", "page"]);

async function main() {
  return await new Command()
    .name("note")
    .globalType("subCommand", subCommandType)
    .env(
      "GITHUB_TOKEN=<github_token:string>",
      "github token",
      { global: true, required: true },
    )
    .env(
      "NOTE_REPO=<note_repo:string>",
      "github repository for note",
      { global: true, required: true },
    )
    .env(
      "NOTE_USER=<note_user:string>",
      "github user for note",
      { global: true, required: true },
    )
    .global()
    .arguments("<subcommand:subCommand>")
    .version("0.0.1")
    .description("note is a tool for memo")
    .command(
      "edit",
      new Command()
        .description("edit a page")
        .action((options) => {
          const client = getGithubClient(
            // @ts-ignore: todo
            options.githubToken,
            // @ts-ignore: todo
            options.noteUser,
            // @ts-ignore: todo
            options.noteRepo,
          );
          new EditAction(client).Do();
        }),
    )
    .command(
      "create",
      // @ts-ignore: todo
      new Command()
        .description("create an book or page")
        .type("createSubCommand", createSubCommandType)
        .arguments("<subcommand:createSubCommand>")
        .command(
          "book",
          new Command()
            .description("create a book")
            .action((options) => {
              const client = getGithubClient(
                // @ts-ignore: todo
                options.githubToken,
                // @ts-ignore: todo
                options.noteUser,
                // @ts-ignore: todo
                options.noteRepo,
              );
              new CreateBookAction(client).Do();
            }),
        )
        .command(
          "page",
          new Command()
            .name("page")
            .description("create a page")
            .action((options) => {
              const client = getGithubClient(
                // @ts-ignore: todo
                options.githubToken,
                // @ts-ignore: todo
                options.noteUser,
                // @ts-ignore: todo
                options.noteRepo,
              );
              new CreatePageAction(client).Do();
            }),
        ),
    )
    .command(
      "delete",
      // @ts-ignore: todo
      new Command()
        .description("delete a book or page")
        .type("deleteubCommand", deleteubCommandType)
        .arguments("<subcommand:deleteubCommand>")
        .command(
          "page",
          new Command()
            .name("page")
            .description("delete a page")
            .action((options) => {
              const client = getGithubClient(
                // @ts-ignore: todo
                options.githubToken,
                // @ts-ignore: todo
                options.noteUser,
                // @ts-ignore: todo
                options.noteRepo,
              );
              new DeletePageAction(client).Do();
            }),
        ),
    )
    .command(
      "show",
      // @ts-ignore: todo
      new Command()
        .description("show a page")
        .action((options) => {
          const client = getGithubClient(
            // @ts-ignore: todo
            options.githubToken,
            // @ts-ignore: todo
            options.noteUser,
            // @ts-ignore: todo
            options.noteRepo,
          );
          new ShowAction(client).Do();
        }),
    )
    .parse(Deno.args);
}

function getGithubClient(token: string, user: string, repo: string) {
  return new GithubClient(token, user, repo);
}

await main();
