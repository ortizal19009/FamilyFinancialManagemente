import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-family-members',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './family-members.html',
  styleUrl: './family-members.scss'
})
export class FamilyMembersComponent implements OnInit {
  private apiService = inject(ApiService);

  members: any[] = [];
  formMember = this.createEmptyMember();

  editingMember: any = null;
  loading = false;
  successMsg = '';
  generatedPassword = '';
  errorMsg = '';

  ngOnInit() {
    this.loadMembers();
  }

  loadMembers() {
    this.apiService.getFamilyMembers().subscribe(data => this.members = data);
  }

  onCreateMember() {
    this.loading = true;
    this.apiService.createFamilyMember(this.formMember).subscribe({
      next: (response) => {
        this.successMsg = response.generated_password
          ? 'Miembro agregado y cuenta creada'
          : 'Miembro agregado';
        this.generatedPassword = response.generated_password ?? '';
        this.resetForm();
        this.loadMembers();
        this.loading = false;
        setTimeout(() => {
          this.successMsg = '';
          this.generatedPassword = '';
        }, 8000);
      },
      error: (error) => {
        this.errorMsg = error?.error?.msg || 'Error al agregar';
        this.loading = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEdit(member: any) {
    this.editingMember = { ...member };
    this.formMember = {
      name: member.name,
      relationship: member.relationship,
      linked_user_email: member.linked_user_email ?? '',
      password: ''
    };
  }

  onUpdateMember() {
    this.loading = true;
    this.apiService.updateFamilyMember(this.editingMember.id, this.formMember).subscribe({
      next: (response) => {
        this.successMsg = response.generated_password
          ? 'Integrante actualizado y cuenta creada'
          : 'Actualizado correctamente';
        this.generatedPassword = response.generated_password ?? '';
        this.resetForm();
        this.loadMembers();
        this.loading = false;
        setTimeout(() => {
          this.successMsg = '';
          this.generatedPassword = '';
        }, 8000);
      },
      error: (error) => {
        this.errorMsg = error?.error?.msg || 'Error al actualizar';
        this.loading = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onDelete(id: number) {
    if (confirm('¿Estás seguro de eliminar este miembro?')) {
      this.apiService.deleteFamilyMember(id).subscribe(() => this.loadMembers());
    }
  }

  onCancelEdit() {
    this.resetForm();
  }

  private resetForm() {
    this.editingMember = null;
    this.formMember = this.createEmptyMember();
  }

  private createEmptyMember() {
    return {
      name: '',
      relationship: 'Esposa',
      linked_user_email: '',
      password: ''
    };
  }
}
