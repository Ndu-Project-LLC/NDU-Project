import 'package:flutter/material.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/utils/file_upload_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';

class DesignSpecificationsCard extends StatelessWidget {
  const DesignSpecificationsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = ProjectDataInherited.of(context);
    final specifications =
        provider.projectData.designManagementData?.specifications ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Design Specifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: Color(0xFF6366F1)),
                onPressed: () => _showAddSpecificationDialog(context, provider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (specifications.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No specifications defined.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: specifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final spec = specifications[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(spec.description),
                  trailing: _buildStatusChip(context, spec, provider),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, DesignSpecification spec,
      ProjectDataProvider provider) {
    Color color;
    switch (spec.status) {
      case 'Validated':
        color = Colors.green;
        break;
      case 'Implemented':
        color = Colors.blue;
        break;
      default:
        color = Colors.orange;
    }

    return InkWell(
      onTap: () => _showStatusDialog(context, spec, provider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          spec.status,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showAddSpecificationDialog(
      BuildContext context, ProjectDataProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Specification'),
        content: VoiceTextField(
          controller: controller,
          decoration:
              const InputDecoration(hintText: 'Enter specification details'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final newSpec =
                    DesignSpecification(description: controller.text);
                final currentData = provider.projectData.designManagementData ??
                    DesignManagementData();
                currentData.specifications.add(newSpec);

                provider.updateProjectData(
                  provider.projectData
                      .copyWith(designManagementData: currentData),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showStatusDialog(BuildContext context, DesignSpecification spec,
      ProjectDataProvider provider) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Update Status'),
        children: ['Defined', 'Validated', 'Implemented'].map((status) {
          return SimpleDialogOption(
            onPressed: () {
              spec.status = status;
              // Trigger update
              final currentData = provider.projectData.designManagementData!;
              // The list is already mutated, but we need to notify listeners
              provider.updateProjectData(
                provider.projectData
                    .copyWith(designManagementData: currentData),
              );
              Navigator.pop(context);
            },
            child: Text(status),
          );
        }).toList(),
      ),
    );
  }
}

class DesignDocumentsCard extends StatelessWidget {
  const DesignDocumentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = ProjectDataInherited.of(context);
    final documents =
        provider.projectData.designManagementData?.documents ?? [];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description,
                    color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Design Documents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    if (documents.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${documents.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (documents.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.folder_open,
                        size: 48,
                        color: const Color(0xFF16A34A).withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No documents linked',
                      style: TextStyle(
                          color: const Color(0xFF16A34A).withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showAddDocumentDialog(context, provider),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Document'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF16A34A),
                        side: const BorderSide(color: Color(0xFF16A34A)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                ...documents.map((doc) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              doc.hasUploadedFile
                                  ? Icons.attach_file
                                  : Icons.description_outlined,
                              size: 16,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doc.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16A34A)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(doc.type,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF16A34A),
                                          )),
                                    ),
                                    if (doc.hasUploadedFile) ...[
                                      const SizedBox(width: 6),
                                      Text(doc.uploadedFileName!,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500),
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (doc.url != null && doc.url!.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.open_in_new,
                                  size: 16, color: Color(0xFF16A34A)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Opening ${doc.url}')),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 28, minHeight: 28),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: Color(0xFFEF4444)),
                            onPressed: () {
                              final currentData = provider
                                      .projectData.designManagementData ??
                                  DesignManagementData();
                              currentData.documents
                                  .removeWhere((d) => d.id == doc.id);
                              provider.updateProjectData(
                                provider.projectData.copyWith(
                                    designManagementData: currentData),
                              );
                              FileUploadHelper.deleteUploadedFile(
                                  doc.uploadedStoragePath);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _showAddDocumentDialog(context, provider),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Document'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF16A34A)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showAddDocumentDialog(
      BuildContext context, ProjectDataProvider provider) {
    final titleController = TextEditingController();
    String docType = 'Output';
    String? uploadedFileName;
    String? uploadedFileUrl;
    String? uploadedStoragePath;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file_outlined,
                    size: 18, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 10),
              const Text('Add Document',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceTextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Document Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: docType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['Input', 'Output', 'Reference'].map((t) {
                    return DropdownMenuItem(value: t, child: Text(t));
                  }).toList(),
                  onChanged: (val) => setDialogState(() => docType = val!),
                ),
                const SizedBox(height: 16),
                // File upload area
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: uploadedFileName != null
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (uploadedFileName != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 20, color: Color(0xFF16A34A)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(uploadedFileName!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: Color(0xFFEF4444)),
                              onPressed: () => setDialogState(() {
                                uploadedFileName = null;
                                uploadedFileUrl = null;
                                uploadedStoragePath = null;
                              }),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 28, minHeight: 28),
                            ),
                          ],
                        ),
                      ] else ...[
                        Icon(Icons.cloud_upload_outlined,
                            size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('Click to upload a document',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text(
                            'PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, TXT, CSV, PNG, JPG',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isUploading
                              ? null
                              : () async {
                                  setDialogState(() => isUploading = true);
                                  final projectId =
                                      ProjectDataHelper.getData(context)
                                          .projectId;
                                  if (projectId == null ||
                                      projectId.isEmpty) {
                                    setDialogState(() => isUploading = false);
                                    return;
                                  }
                                  final result =
                                      await FileUploadHelper.pickAndUpload(
                                    folder: 'design-documents',
                                    projectId: projectId,
                                    allowedExtensions:
                                        FileUploadHelper.documentExtensions,
                                  );
                                  if (result != null) {
                                    setDialogState(() {
                                      uploadedFileName = result.fileName;
                                      uploadedFileUrl = result.downloadUrl;
                                      uploadedStoragePath = result.storagePath;
                                      isUploading = false;
                                    });
                                  } else {
                                    setDialogState(() => isUploading = false);
                                  }
                                },
                          icon: isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.attach_file, size: 18),
                          label: Text(
                              isUploading ? 'Uploading...' : 'Choose File'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF16A34A),
                            side: const BorderSide(color: Color(0xFF16A34A)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isEmpty && uploadedFileName == null) {
                  return;
                }
                final newDoc = DesignDocument(
                  title: titleController.text.isEmpty
                      ? uploadedFileName ?? 'Untitled'
                      : titleController.text,
                  type: docType,
                  url: uploadedFileUrl,
                  uploadedFileName: uploadedFileName,
                  uploadedStoragePath: uploadedStoragePath,
                );
                final currentData =
                    provider.projectData.designManagementData ??
                        DesignManagementData();
                currentData.documents.add(newDoc);

                provider.updateProjectData(
                  provider.projectData
                      .copyWith(designManagementData: currentData),
                );
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class DesignToolsCard extends StatelessWidget {
  const DesignToolsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = ProjectDataInherited.of(context);
    final tools = provider.projectData.designManagementData?.tools ?? [];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.construction,
                    color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Design Tools',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    if (tools.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${tools.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tools.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.handyman,
                        size: 48,
                        color: const Color(0xFFD97706).withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No tools configured',
                      style: TextStyle(
                          color: const Color(0xFFD97706).withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _showAddToolDialog(context, provider),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Tool'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFFD97706)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                ...tools.map((tool) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              tool.hasUploadedFile
                                  ? Icons.attach_file
                                  : (tool.isInternal ? Icons.dns : Icons.public),
                              size: 16,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tool.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tool.isInternal ? 'Internal' : 'External',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                    if (tool.hasUploadedFile) ...[
                                      const SizedBox(width: 6),
                                      Text(tool.uploadedFileName!,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500),
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (tool.url.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.open_in_new,
                                  size: 16, color: Color(0xFFD97706)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Opening ${tool.url}')),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 28, minHeight: 28),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 14, color: Color(0xFFEF4444)),
                            onPressed: () {
                              final currentData = provider
                                      .projectData.designManagementData ??
                                  DesignManagementData();
                              currentData.tools.remove(tool);
                              provider.updateProjectData(
                                provider.projectData.copyWith(
                                    designManagementData: currentData),
                              );
                              FileUploadHelper.deleteUploadedFile(
                                  tool.uploadedStoragePath);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _showAddToolDialog(context, provider),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Tool'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showAddToolDialog(BuildContext context, ProjectDataProvider provider) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    bool isInternal = false;
    String? uploadedFileName;
    String? uploadedFileUrl;
    String? uploadedStoragePath;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.build_outlined,
                    size: 18, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              const Text('Add Design Tool',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceTextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tool Name'),
                ),
                const SizedBox(height: 8),
                VoiceTextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'URL (Optional)'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Internal Tool'),
                  value: isInternal,
                  onChanged: (val) =>
                      setDialogState(() => isInternal = val!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                // File upload area
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: uploadedFileName != null
                          ? const Color(0xFFD97706)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (uploadedFileName != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 20, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(uploadedFileName!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: Color(0xFFEF4444)),
                              onPressed: () => setDialogState(() {
                                uploadedFileName = null;
                                uploadedFileUrl = null;
                                uploadedStoragePath = null;
                              }),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 28, minHeight: 28),
                            ),
                          ],
                        ),
                      ] else ...[
                        Icon(Icons.cloud_upload_outlined,
                            size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('Upload design documents or tool files',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text('PDF, DOC, DOCX, FIG, SKETCH, XD, PNG, JPG, ZIP',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isUploading
                              ? null
                              : () async {
                                  setDialogState(() => isUploading = true);
                                  final projectId =
                                      ProjectDataHelper.getData(context)
                                          .projectId;
                                  if (projectId == null ||
                                      projectId.isEmpty) {
                                    setDialogState(() => isUploading = false);
                                    return;
                                  }
                                  final result =
                                      await FileUploadHelper.pickAndUpload(
                                    folder: 'design-tools',
                                    projectId: projectId,
                                    allowedExtensions:
                                        FileUploadHelper.toolExtensions,
                                  );
                                  if (result != null) {
                                    setDialogState(() {
                                      uploadedFileName = result.fileName;
                                      uploadedFileUrl = result.downloadUrl;
                                      uploadedStoragePath = result.storagePath;
                                      isUploading = false;
                                    });
                                  } else {
                                    setDialogState(() => isUploading = false);
                                  }
                                },
                          icon: isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.attach_file, size: 18),
                          label: Text(
                              isUploading ? 'Uploading...' : 'Choose File'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            side: const BorderSide(color: Color(0xFFD97706)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty && uploadedFileName == null) {
                  return;
                }
                final newTool = DesignToolLink(
                  name: nameController.text.isEmpty
                      ? uploadedFileName ?? 'Untitled Tool'
                      : nameController.text,
                  url: urlController.text.isEmpty
                      ? (uploadedFileUrl ?? '')
                      : urlController.text,
                  isInternal: isInternal,
                  uploadedFileName: uploadedFileName,
                  uploadedStoragePath: uploadedStoragePath,
                );
                final currentData =
                    provider.projectData.designManagementData ??
                        DesignManagementData();
                currentData.tools.add(newTool);

                provider.updateProjectData(
                  provider.projectData
                      .copyWith(designManagementData: currentData),
                );
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
