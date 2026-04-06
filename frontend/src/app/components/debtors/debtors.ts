import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-debtors',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './debtors.html',
  styleUrl: './debtors.scss'
})
export class DebtorsComponent implements OnInit {
  private apiService = inject(ApiService);

  debtors: any[] = [];
  
  newDebtor = {
    name: '',
    amount_owed: 0,
    description: '',
    due_date: '',
    status: 'pendiente'
  };

  loading = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadDebtors();
  }

  loadDebtors() {
    this.apiService.getDebtors().subscribe(data => {
      this.debtors = data;
    });
  }

  onSubmit() {
    this.loading = true;
    this.apiService.createDebtor(this.newDebtor).subscribe({
      next: () => {
        this.successMsg = 'Deudor registrado correctamente';
        this.resetForm();
        this.loadDebtors();
        this.loading = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al registrar al deudor';
        this.loading = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onUpdateStatus(id: number, newStatus: string) {
    this.apiService.updateDebtorStatus(id, { status: newStatus }).subscribe(() => {
      this.loadDebtors();
    });
  }

  resetForm() {
    this.newDebtor = {
      name: '',
      amount_owed: 0,
      description: '',
      due_date: '',
      status: 'pendiente'
    };
  }

  getTotalOwed(): number {
    return this.debtors
      .filter(d => d.status === 'pendiente')
      .reduce((acc, curr) => acc + curr.amount_owed, 0);
  }
}
