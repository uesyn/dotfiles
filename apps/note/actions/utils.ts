export async function selectIssue(
  issues: { title: string; number: number }[],
): Promise<{ issue_number: number; title: string } | undefined> {
  const encoder = new TextEncoder();
  const delim = ") ";

  const p = Deno.run({
    cmd: ["fzf"],
    stdin: "piped",
    stdout: "piped",
  });
  for (const issue of issues) {
    p.stdin?.write(encoder.encode(issue.number + delim + issue.title + "\n"));
  }

  const selectedLine = new TextDecoder().decode(await p.output()).trim();
  await p.status();
  if (selectedLine.length === 0) {
    return undefined;
  }
  const idTitle = selectedLine.split(delim, 2);
  return { issue_number: parseInt(idTitle[0]), title: idTitle[1] };
}

export async function selectComment(
  comments: { id: number; body?: string }[],
): Promise<{ comment_id: number; title: string } | undefined> {
  const encoder = new TextEncoder();
  const delim = ") ";
  const p = Deno.run({
    cmd: ["fzf"],
    stdin: "piped",
    stdout: "piped",
  });
  for (const comment of comments) {
    const title = comment.body?.split("\n")[0].replaceAll("\r", "").replace(
      /^#*\s*/,
      "",
    );
    p.stdin?.write(encoder.encode(comment.id + delim + title + "\n"));
  }
  const selectedLine = new TextDecoder().decode(await p.output()).trim();
  const status = await p.status();
  if (!status.success) {
    return undefined;
  }
  if (selectedLine.length === 0) {
    return undefined;
  }
  const idTitle = selectedLine.split(delim, 2);
  return { comment_id: parseInt(idTitle[0]), title: idTitle[1] };
}

export function getEditorCommand(): string[] {
  const command: string[] = [Deno.env.get("EDITOR") ?? "vim"];
  const options = (Deno.env.get("EDITOR_OPTIONS") ?? "").split(",");
  if (options.length > 1) {
    command.push(...options);
  }
  return command;
}
